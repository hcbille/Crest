import Foundation
import Observation

@Observable
@MainActor
final class BrowserQuickWindowModel {
    private(set) var presentedRequest: BrowserQuickWindowRequest
    private(set) var selectedAssignment: BrowserSpaceRuntimeAssignment
    private(set) var pageLease: BrowserTransientPageLease?
    private(set) var releasedPageSnapshot: BrowserTransientPageSnapshot?
    private(set) var wasPromoted = false
    let activityClock: BrowserTransientActivityClock

    /// The core page the released snapshot names, unloaded with its state
    /// kept so the core still knows what it showed until the snapshot goes.
    @ObservationIgnored private var unloadedPage: CorePage?
    @ObservationIgnored let browser: BrowserStore
    @ObservationIgnored let pages: BrowserPagePool?
    @ObservationIgnored private let spaceAccess: BrowserSpaceAccessController
    @ObservationIgnored private let supportsLivePagePromotion: Bool
    @ObservationIgnored private let preferences: BrowserTransientBrowsingPreferences
    @ObservationIgnored private let requestLifecycle: BrowserQuickWindowRequestLifecycle

    init(
        request: BrowserQuickWindowRequest,
        browser: BrowserStore,
        pages: BrowserPagePool,
        spaceAccess: BrowserSpaceAccessController,
        supportsLivePagePromotion: Bool,
        preferences: BrowserTransientBrowsingPreferences,
        requestLifecycle: BrowserQuickWindowRequestLifecycle
    ) {
        presentedRequest = request
        selectedAssignment = request.assignment
        self.browser = browser
        self.pages = pages
        self.spaceAccess = spaceAccess
        self.supportsLivePagePromotion = supportsLivePagePromotion
        self.preferences = preferences
        self.requestLifecycle = requestLifecycle
        activityClock = BrowserTransientActivityClock()
        browser.core.engines.observeRecords(self) { [weak self] in self?.recordActivity(after: $0) }
    }

    init(
        previewing request: BrowserQuickWindowRequest,
        browser: BrowserStore,
        spaceAccess: BrowserSpaceAccessController
    ) {
        presentedRequest = request
        selectedAssignment = request.assignment
        self.browser = browser
        pages = nil
        self.spaceAccess = spaceAccess
        supportsLivePagePromotion = false
        preferences = .isolated
        requestLifecycle = .preview
        activityClock = BrowserTransientActivityClock(
            now: Date(timeIntervalSince1970: 0)
        )
    }

    /// The Space the Quick Window browses, as the read model holds it.
    var spaceModel: SpaceModel? {
        browser.spaceModel(matching: selectedAssignment)
    }

    /// The Spaces the Quick Window may move to or unlock: none being deleted, and
    /// none locked but its own.
    var availableSpaceModels: [SpaceModel] {
        BrowserTransientSessionPolicy.availableSpaces(
            in: browser, requestSpaceID: selectedAssignment.spaceID, isLocked: spaceAccess.isLocked)
    }

    /// The Space the page pool opens the Quick Window's page in, as the
    /// session copy holds it. TRANSITIONAL until Lane 2's page pool takes the
    /// read model's Space.
    private var leaseSpace: BrowserSpace? {
        browser.space(matching: selectedAssignment)
    }

    var page: BrowserPage? {
        pageLease?.page
    }

    func windowTitle(for request: BrowserQuickWindowRequest) -> String {
        let fallback = String(localized: "Quick Window")
        // A Binding captured by the action lifecycle can read its older value
        // during SwiftUI rendering. Compare the scene's current value directly.
        guard presentedRequest.hasSamePresentationIdentity(as: request),
            let space = spaceModel, !spaceAccess.isLocked(space)
        else { return fallback }
        return BrowserWindowTitle.resolve(
            page: page,
            storedTitle: releasedPageSnapshot?.title,
            url: releasedPageSnapshot?.url ?? presentedRequest.initialURL,
            fallback: fallback
        )
    }

    func preparePage(isActive: Bool) {
        guard isCurrentRequest else {
            releasePageRetainingSnapshot()
            return
        }
        guard let space = spaceModel,
            let url = page?.live.documentURL
                ?? releasedPageSnapshot?.url
                ?? presentedRequest.initialURL
        else {
            releaseUnavailableLease()
            return
        }
        guard !spaceAccess.isLocked(space) else {
            releaseForUnavailableSpace()
            return
        }
        let assignment = BrowserSpaceRuntimeAssignment(space: space)
        guard assignment == selectedAssignment else {
            releaseUnavailableLease()
            return
        }
        if let pageLease,
            pageLease.assignment == assignment,
            pageLease.canBeReused
        {
            pageLease.setActive(isActive)
            return
        }
        pageLease?.release()
        guard let pages, let leaseSpace else { return }
        pageLease = pages.makeTransientPageLease(
            url: url,
            in: leaseSpace,
            onUserActivity: recordUserActivity
        )
        if pageLease != nil {
            forgetReleasedSnapshot()
        }
        pageLease?.setActive(isActive)
    }

    func open(_ url: URL, isActive: Bool) {
        guard isCurrentRequest,
            let space = spaceModel,
            BrowserSpaceRuntimeAssignment(space: space)
                == selectedAssignment,
            !spaceAccess.isLocked(space)
        else { return }
        activityClock.recordActivity(restartsTimerImmediately: true)
        guard
            revisePresentedRequest(
                url: url,
                assignment: selectedAssignment
            )
        else { return }
        if let page {
            page.corePage.navigate(to: url.absoluteString)
            return
        }
        guard let pages, let leaseSpace else { return }
        pageLease = pages.makeTransientPageLease(
            url: url,
            in: leaseSpace,
            onUserActivity: recordUserActivity
        )
        if pageLease != nil {
            forgetReleasedSnapshot()
        }
        pageLease?.setActive(isActive)
    }

    /// Moves the Quick Window to the Space `assignment` names, while that
    /// Space keeps its profile and is unlocked.
    func selectSpace(_ assignment: BrowserSpaceRuntimeAssignment) {
        guard isCurrentRequest,
            let candidate = browser.spaceModel(matching: assignment),
            !spaceAccess.isLocked(candidate),
            assignment != selectedAssignment
        else { return }
        activityClock.recordActivity(restartsTimerImmediately: true)
        let currentURL = currentSnapshot?.url ?? presentedRequest.initialURL
        guard
            revisePresentedRequest(
                url: currentURL ?? presentedRequest.url,
                assignment: assignment
            )
        else { return }
        pageLease?.release()
        pageLease = nil
        forgetReleasedSnapshot()
        selectedAssignment = assignment
        // Moving a page, not an empty lookup, remembers the Space for its site.
        if let currentURL {
            preferences.rememberSpace(assignment.spaceID, for: currentURL)
        }
    }

    @discardableResult
    func promote(to assignment: BrowserSpaceRuntimeAssignment) -> Bool {
        activityClock.recordActivity(restartsTimerImmediately: true)
        guard isCurrentRequest, !wasPromoted, let pages else { return false }
        let url = currentSnapshot?.url ?? presentedRequest.initialURL
        let movesSpace = assignment != presentedRequest.assignment
        // A page memory pressure took back comes back to be kept.
        if pageLease?.page == nil { pageLease?.restore() }
        guard
            let outcome = BrowserTransientPagePromotion(
                page: pageLease?.page?.corePage, url: url, destinationAssignment: assignment,
                supportsLiveAdoption: supportsLivePagePromotion
            ).perform(
                in: browser, isLocked: spaceAccess.isLocked,
                adoptPage: { [pageLease] tabID, space in
                    guard let pageLease else { return false }
                    return pages.adoptTransientPage(pageLease, as: tabID, in: space)
                })
        else { return false }
        if movesSpace, let url {
            preferences.rememberSpace(assignment.spaceID, for: url)
        }
        wasPromoted = true
        if outcome != .adoptedLivePage { pageLease?.release() }
        pages.select()
        return true
    }

    /// A navigation the core recorded for this Quick Window's page is
    /// activity, which keeps the window from archiving itself while in use.
    private func recordActivity(after records: Engines.PageRecords) {
        guard isCurrentRequest, let page, records.recordedNavigation(of: page.corePage.id) else { return }
        activityClock.recordActivity(restartsTimerImmediately: true)
    }

    func updatePresentedURL(_ url: URL) {
        revisePresentedRequest(
            url: url,
            assignment: selectedAssignment
        )
    }

    /// Files the page the window shows, or showed last, in the archive. The
    /// core archives a page once, and never one kept as a tab.
    @discardableResult
    func archivePageIfNeeded() -> Bool {
        guard let snapshot = currentSnapshot else { return false }
        return browser.archiveTransientPage(snapshot.pageID, matching: snapshot.assignment)
    }

    func releaseForUnavailableSpace() {
        releasePageRetainingSnapshot()
    }

    func releaseForDismissal() {
        if !wasPromoted {
            archivePageIfNeeded()
        }
        pageLease?.release()
        pageLease = nil
        forgetReleasedSnapshot()
    }

    func restorePage() {
        activityClock.recordActivity(restartsTimerImmediately: true)
        guard isCurrentRequest else {
            releasePageRetainingSnapshot()
            return
        }
        guard let pageLease else { return }
        guard let space = browser.spaceModel(matching: pageLease.assignment) else {
            releaseUnavailableLease()
            return
        }
        guard !spaceAccess.isLocked(space) else {
            releaseForUnavailableSpace()
            return
        }
        pageLease.restore()
    }

    func setActive(_ isActive: Bool) {
        guard isCurrentRequest else {
            releasePageRetainingSnapshot()
            return
        }
        guard let space = spaceModel,
            !spaceAccess.isLocked(space)
        else {
            releaseForUnavailableSpace()
            return
        }
        pageLease?.setActive(isActive)
        if isActive {
            activityClock.recordActivity(restartsTimerImmediately: true)
        }
    }

    func recordUserActivity() {
        activityClock.recordActivity()
    }

    /// The inactivity wait the window restarts when its activity or its
    /// lifetime changes.
    var archiveTimer: BrowserTransientArchiveTimer {
        BrowserTransientArchiveTimer(activity: activityClock.revision, lifetime: preferences.archiveLifetime)
    }

    func waitUntilArchiveIsDue() async -> Bool {
        guard isCurrentRequest,
            let lifetime = preferences.archiveLifetime,
            await activityClock.waitUntilInactive(for: lifetime),
            isCurrentRequest
        else { return false }
        return true
    }

    private func releaseUnavailableLease() {
        guard let pageLease,
            browser.spaceModel(matching: pageLease.assignment) == nil
        else {
            return
        }
        pageLease.release()
        self.pageLease = nil
        forgetReleasedSnapshot()
    }

    @discardableResult
    private func revisePresentedRequest(
        url: URL,
        assignment: BrowserSpaceRuntimeAssignment
    ) -> Bool {
        let expected = presentedRequest
        guard url != presentedRequest.url || assignment != presentedRequest.assignment else {
            return isCurrentRequest
        }
        let revised = presentedRequest.retargeted(
            to: url,
            assignment: assignment
        )
        guard requestLifecycle.replace(expected, with: revised) else {
            releasePageRetainingSnapshot()
            return false
        }
        presentedRequest = revised
        return true
    }

    private var isCurrentRequest: Bool {
        requestLifecycle.isCurrent(presentedRequest)
    }

    private var currentSnapshot: BrowserTransientPageSnapshot? {
        pageLease.map(snapshot) ?? releasedPageSnapshot
    }

    private func snapshot(
        _ lease: BrowserTransientPageLease
    ) -> BrowserTransientPageSnapshot {
        BrowserTransientPageSnapshot(
            assignment: lease.assignment,
            url: lease.recoverableURL,
            title: lease.page?.live.title,
            pageID: lease.pageID
        )
    }

    /// Lets the page go but keeps what it shows: the snapshot the window
    /// archives on dismissal, and the core's memory of the page, both until
    /// the snapshot goes.
    private func releasePageRetainingSnapshot() {
        guard let pageLease else { return }
        let retained = snapshot(pageLease)
        forgetReleasedSnapshot()
        releasedPageSnapshot = retained
        unloadedPage = pageLease.unload()
        self.pageLease = nil
    }

    /// Drops the released page's snapshot, and releases its page for good so
    /// the core forgets what it showed too.
    private func forgetReleasedSnapshot() {
        releasedPageSnapshot = nil
        unloadedPage?.release(keepingState: false)
        unloadedPage = nil
    }
}
