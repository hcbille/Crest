import Foundation
import Observation

@Observable
@MainActor
final class MobileBrowserTransientOverlayModel {
    let request: MobileBrowserTransientRequest
    private(set) var pageLease: MobileBrowserTransientPageLease?
    private(set) var releasedPageSnapshot: BrowserTransientPageSnapshot?
    private(set) var wasPromoted = false

    /// The core page the released snapshot names, unloaded with its state
    /// kept so the core still knows what it showed until the snapshot goes.
    @ObservationIgnored private var unloadedPage: CorePage?
    @ObservationIgnored let browser: BrowserStore
    @ObservationIgnored private let pages: MobileBrowserPageStore?
    @ObservationIgnored private let coordinator: BrowserTransientBrowsingCoordinator
    @ObservationIgnored private let spaceAccess: BrowserSpaceAccessController
    @ObservationIgnored private let preferences: BrowserTransientBrowsingPreferences
    @ObservationIgnored private let activityClock: BrowserTransientActivityClock
    @ObservationIgnored private let didPromote: () -> Void

    init(
        request: MobileBrowserTransientRequest,
        browser: BrowserStore,
        pages: MobileBrowserPageStore,
        coordinator: BrowserTransientBrowsingCoordinator,
        spaceAccess: BrowserSpaceAccessController,
        preferences: BrowserTransientBrowsingPreferences,
        didPromote: @escaping () -> Void = {}
    ) {
        self.request = request
        self.browser = browser
        self.pages = pages
        self.coordinator = coordinator
        self.spaceAccess = spaceAccess
        self.preferences = preferences
        self.didPromote = didPromote
        activityClock = BrowserTransientActivityClock()
        browser.core.engines.observeRecords(self) { [weak self] in self?.recordActivity(after: $0) }
        browser.core.followClosedTransientPages(self) { [weak self] in self?.pageClosed($0) }
    }

    init(
        previewing request: MobileBrowserTransientRequest,
        browser: BrowserStore,
        coordinator: BrowserTransientBrowsingCoordinator,
        spaceAccess: BrowserSpaceAccessController
    ) {
        self.request = request
        self.browser = browser
        pages = nil
        self.coordinator = coordinator
        self.spaceAccess = spaceAccess
        preferences = .isolated
        didPromote = {}
        activityClock = BrowserTransientActivityClock(
            now: Date(timeIntervalSince1970: 0)
        )
    }

    /// The Space the overlay browses, as the read model holds it.
    var spaceModel: SpaceModel? {
        browser.spaceModel(matching: request.spaceAssignment)
    }

    /// The Spaces the overlay may move to or unlock: none being deleted, and
    /// none locked but its own.
    var availableSpaceModels: [SpaceModel] {
        BrowserTransientSessionPolicy.availableSpaces(
            in: browser, requestSpaceID: request.spaceID, isLocked: spaceAccess.isLocked)
    }

    var page: MobileBrowserPage? {
        pageLease?.page
    }

    var motionState: BrowserPeekMotionState? {
        guard case .peek(let peek) = request else { return nil }
        return coordinator.motionState(for: peek)
    }

    var isSelected: Bool {
        guard case .peek(let peek) = request else { return true }
        return peek.isSelected(in: browser)
    }

    var hasSource: Bool {
        guard case .peek(let peek) = request else { return spaceModel != nil }
        return peek.hasSource(in: browser)
    }

    /// The inactivity wait a Quick Window restarts when its activity or its
    /// lifetime changes.
    var archiveTimer: BrowserTransientArchiveTimer {
        BrowserTransientArchiveTimer(activity: activityClock.revision, lifetime: preferences.archiveLifetime)
    }

    @discardableResult
    func preparePage(isActive: Bool) -> Bool {
        let space: SpaceModel
        switch sourceDisposition {
        case .notPresented:
            releasePageRetainingQuickWindowSnapshot()
            return false
        case .sourceMissing:
            dismissUnavailableRequest()
            return false
        case .sourceLocked:
            setSourceLocked(true)
            return false
        case .usable(let usableSpace):
            space = usableSpace
        }
        if let pageLease,
            BrowserTransientSessionPolicy.reusesLease(
                leaseAssignment: pageLease.assignment,
                requestAssignment: request.spaceAssignment,
                leaseCanBeReused: pageLease.page != nil
                    || pageLease.wasReleasedForMemoryPressure
            )
        {
            pageLease.setActive(isActive && isSelected)
            return true
        }
        pageLease?.release()
        guard let pages else { return true }
        if case .peek(let peek) = request {
            pageLease = pages.makePeekPageLease(
                request: peek, in: space,
                onDownloadOnlyNavigation: { [weak coordinator] in
                    coordinator?.dismissPeek(peek)
                })
        } else {
            pageLease = pages.makeTransientPageLease(
                url: releasedPageSnapshot?.url ?? request.url,
                in: space,
                onUserActivity: recordUserActivity,
                onDownloadOnlyNavigation: { [weak self] in
                    self?.dismissDownloadOnlyNavigation()
                }
            )
        }
        guard let pageLease else {
            dismissUnavailableRequest()
            return false
        }
        forgetReleasedSnapshot()
        pageLease.setActive(isActive && isSelected)
        return true
    }

    func setActive(_ isActive: Bool) {
        switch sourceDisposition {
        case .notPresented:
            releasePageRetainingQuickWindowSnapshot()
            return
        case .sourceMissing:
            dismissUnavailableRequest()
            return
        case .sourceLocked:
            setSourceLocked(true)
            return
        case .usable:
            break
        }
        pageLease?.setActive(isActive && isSelected)
        guard isActive else { return }
        activityClock.recordActivity(restartsTimerImmediately: true)
    }

    func setSourceLocked(_ isLocked: Bool) {
        guard isLocked else { return }
        releasePageRetainingQuickWindowSnapshot()
    }

    func setSourceAvailable(_ isAvailable: Bool) {
        guard !isAvailable else { return }
        dismissUnavailableRequest()
    }

    /// The core closed this request's page: it closed itself, as a page
    /// another page opened may, or its engine closed it. The Peek or Quick
    /// Window goes with it, keeping nothing of it.
    private func pageClosed(_ closed: TransientPageClosed) {
        guard pageLease?.pageID == closed.pageID else { return }
        dismissUnavailableRequest()
    }

    /// A navigation the core recorded for this request's page is activity,
    /// which keeps a Quick Window from archiving itself while in use.
    private func recordActivity(after records: Engines.PageRecords) {
        guard isCurrentRequest, let page = pageLease?.page, records.recordedNavigation(of: page.corePage.id) else {
            return
        }
        activityClock.recordActivity(restartsTimerImmediately: true)
    }

    func recordUserActivity() {
        activityClock.recordActivity()
    }

    func restorePage() {
        activityClock.recordActivity(restartsTimerImmediately: true)
        guard isCurrentRequest else {
            releasePageRetainingQuickWindowSnapshot()
            return
        }
        guard let pageLease else { return }
        switch disposition(ofSpaceMatching: pageLease.assignment) {
        case .notPresented:
            releasePageRetainingQuickWindowSnapshot()
        case .sourceMissing:
            dismissUnavailableRequest()
        case .sourceLocked:
            setSourceLocked(true)
        case .usable:
            pageLease.restore()
        }
    }

    @discardableResult
    func promote(to destinationAssignment: BrowserSpaceRuntimeAssignment) -> Bool {
        activityClock.recordActivity(restartsTimerImmediately: true)
        guard let pages,
            isCurrentRequest,
            !wasPromoted,
            let pageLease,
            let page = pageLease.page,
            let outcome = BrowserTransientPagePromotion(
                page: page.corePage,
                url: page.live.documentURL ?? request.url,
                destinationAssignment: destinationAssignment
            ).perform(
                in: browser,
                isLocked: spaceAccess.isLocked,
                adoptPage: { tabID, destination in
                    pages.adoptTransientPage(pageLease, as: tabID, in: destination)
                }
            )
        else { return false }

        // Keeping a Quick Window's page in another Space remembers that Space for its site.
        if case .quickWindow(let quickWindowRequest) = request, destinationAssignment != quickWindowRequest.assignment,
            let pageURL = page.live.documentURL ?? quickWindowRequest.initialURL
        {
            preferences.rememberSpace(destinationAssignment.spaceID, for: pageURL)
        }
        wasPromoted = true
        if outcome == .openedNewPage {
            pageLease.release()
            pages.select()
        }
        dismissCoordinatorRequest()
        didPromote()
        return true
    }

    func selectLockedSpace(_ assignment: BrowserSpaceRuntimeAssignment) {
        guard isCurrentRequest else { return }
        switch request {
        case .quickWindow:
            changeQuickWindowSpace(to: assignment)
        case .peek(let peekRequest):
            guard let candidate = browser.spaceModel(matching: assignment),
                !spaceAccess.isLocked(candidate),
                coordinator.dismissPeek(peekRequest)
            else { return }
            browser.selectSpace(assignment.spaceID)
        }
    }

    func dismiss() {
        dismissCoordinatorRequest()
    }

    func dismissUnavailableRequest() {
        guard isCurrentRequest else { return }
        pageLease?.release()
        pageLease = nil
        forgetReleasedSnapshot()
        switch request {
        case .peek(let peekRequest):
            coordinator.dismissPeek(peekRequest)
        case .quickWindow(let quickWindowRequest):
            coordinator.dismissQuickWindow(quickWindowRequest)
        }
    }

    func handleDisappearance() {
        guard !wasPromoted else { return }
        archiveQuickWindowIfNeeded()
        if !request.isQuickWindow && isCurrentRequest {
            pageLease?.setActive(false)
        } else {
            pageLease?.release()
        }
        pageLease = nil
        forgetReleasedSnapshot()
    }

    func autoArchiveAfterInactivity() async {
        guard request.isQuickWindow,
            isCurrentRequest,
            let lifetime = preferences.archiveLifetime,
            await activityClock.waitUntilInactive(for: lifetime)
        else { return }
        dismissCoordinatorRequest()
    }

    private func dismissCoordinatorRequest() {
        guard isCurrentRequest else { return }
        switch request {
        case .peek(let peekRequest):
            coordinator.dismissPeek(peekRequest)
        case .quickWindow(let quickWindowRequest):
            archiveQuickWindowIfNeeded()
            coordinator.dismissQuickWindow(quickWindowRequest)
        }
    }

    private func dismissDownloadOnlyNavigation() {
        guard isCurrentRequest else { return }
        forgetReleasedSnapshot()
        switch request {
        case .peek(let peekRequest):
            coordinator.dismissPeek(peekRequest)
        case .quickWindow(let quickWindowRequest):
            coordinator.dismissQuickWindow(quickWindowRequest)
        }
    }

    /// Files a Quick Window's page in the archive. The core archives a page
    /// once, and never one kept as a tab.
    private func archiveQuickWindowIfNeeded() {
        guard request.isQuickWindow, let snapshot = currentSnapshot else { return }
        browser.archiveTransientPage(snapshot.pageID, matching: snapshot.assignment)
    }

    private func changeQuickWindowSpace(
        to destinationAssignment: BrowserSpaceRuntimeAssignment
    ) {
        guard isCurrentRequest,
            case .quickWindow(let quickWindowRequest) = request,
            destinationAssignment.spaceID != quickWindowRequest.spaceID,
            let destination = browser.spaceModel(matching: destinationAssignment),
            !spaceAccess.isLocked(destination)
        else { return }
        let pageURL = currentSnapshot?.url ?? quickWindowRequest.initialURL
        let currentURL = pageURL ?? quickWindowRequest.url
        // Moving a page, not an empty lookup, remembers the Space for its site.
        if let pageURL {
            preferences.rememberSpace(destinationAssignment.spaceID, for: pageURL)
        }
        pageLease?.release()
        pageLease = nil
        forgetReleasedSnapshot()
        coordinator.presentQuickWindow(
            quickWindowRequest.retargeted(
                to: currentURL,
                assignment: destinationAssignment
            )
        )
    }

    private var isCurrentRequest: Bool {
        switch request {
        case .peek(let peekRequest):
            coordinator.isPresentingPeek(peekRequest)
        case .quickWindow(let quickWindowRequest):
            coordinator.isPresentingQuickWindow(quickWindowRequest)
        }
    }

    private var sourceDisposition: BrowserTransientLeaseDisposition {
        disposition(ofSpaceMatching: request.spaceAssignment)
    }

    /// Whether the page may be kept in the Space `assignment` names, and the
    /// Space of the read model its page opens in.
    private func disposition(
        ofSpaceMatching assignment: BrowserSpaceRuntimeAssignment
    ) -> BrowserTransientLeaseDisposition {
        BrowserTransientSessionPolicy.disposition(
            isPresentingRequest: isCurrentRequest,
            space: hasSource ? browser.spaceModel(matching: assignment) : nil,
            isLocked: spaceAccess.isLocked
        )
    }

    /// Lets the page go; a Quick Window keeps what it shows: the snapshot it
    /// archives on dismissal, and the core's memory of the page, both until
    /// the snapshot goes.
    private func releasePageRetainingQuickWindowSnapshot() {
        guard let pageLease else { return }
        if request.isQuickWindow {
            let retained = snapshot(pageLease)
            forgetReleasedSnapshot()
            releasedPageSnapshot = retained
            unloadedPage = pageLease.unload()
        } else {
            pageLease.release()
        }
        self.pageLease = nil
    }

    /// Drops the released page's snapshot, and releases its page for good so
    /// the core forgets what it showed too.
    private func forgetReleasedSnapshot() {
        releasedPageSnapshot = nil
        unloadedPage?.release(keepingState: false)
        unloadedPage = nil
    }

    private var currentSnapshot: BrowserTransientPageSnapshot? {
        pageLease.map(snapshot) ?? releasedPageSnapshot
    }

    private func snapshot(
        _ lease: MobileBrowserTransientPageLease
    ) -> BrowserTransientPageSnapshot {
        BrowserTransientPageSnapshot(
            assignment: lease.assignment,
            url: lease.recoverableURL,
            title: lease.page?.live.title,
            pageID: lease.pageID
        )
    }
}
