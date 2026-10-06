import AppKit
import Observation
import SwiftUI

/// Native presentation state only. Installation, permissions, pinning, workers,
/// and package storage remain owned by Chromium's independent Space profiles.
@Observable @MainActor
final class ChromiumExtensionStore {
    struct Installed: Identifiable {
        let id: String
        let name: String
        let version: String
        let detail: String
        let icon: NSImage?
        let enabled: Bool
        let permissions: [String]
        let webStore: Bool
        let options: String
        init(_ item: InstalledExtension) {
            id = item.id
            name = item.name.isEmpty ? item.id : item.name
            version = item.version
            detail = item.description
            icon = item.icon.flatMap(NSImage.init(extensionIcon:))
            enabled = item.enabled
            permissions = item.permissions
            webStore = item.fromWebStore
            options = item.optionsURL ?? ""
        }
    }
    var revision = 0
    private(set) var installed: [UUID: [Installed]] = [:]
    private(set) var installation: ChromiumExtensionInstallation?
    @ObservationIgnored private var popover: NSPopover?
    @ObservationIgnored private var windowClosed: NSObjectProtocol?
    /// The one-point view the install review is anchored to. It belongs to the
    /// window's own hosting view and is removed with the review.
    @ObservationIgnored private var anchorSpot: NSView?
    /// Runs when the presented install operation ends, however it ended. The
    /// Chrome Web Store listing that started it uses this to restate its own
    /// button instead of leaving it in the progress label.
    @ObservationIgnored private var installCompletion: (@MainActor () -> Void)?

    var spaces: [BrowserSpaceIdentity] { ChromiumComposition.extensionSpaces }
    /// Whether this Space's engine profile may be read and prepared here.
    ///
    /// Ownership is decided by `(spaceID, profileID)` against the store family
    /// that owns the window asking, not by identity against one global list: a
    /// window's own store publishes its Spaces before the application-wide list
    /// a start-up read would see. A Space from an unrelated family — another
    /// family's window, a borrowed settings workspace, a private window, which
    /// has no persistent engine profile of its own — and a locked Space are all
    /// refused. Callers with no window fall back to the application list.
    func authorized(_ space: BrowserSpaceIdentity, in browser: BrowserStore? = nil) -> Bool {
        guard !ChromiumComposition.isSpaceLocked(space) else { return false }
        guard let browser else {
            return spaces.contains { $0.id == space.id && $0.profileID == space.profileID }
        }
        guard ChromiumComposition.ownsExtensionProfiles(browser) else { return false }
        return browser.spaceModel(matching: space.assignment) != nil
    }
    func refresh() {
        revision &+= 1
        guard ChromiumComposition.chromiumEngine != nil else { return }
        let profiles = Set(spaces.map { $0.profileID })
        installed = installed.filter { profiles.contains($0.key) }
        for space in spaces where installed[space.profileID] != nil {
            installed[space.profileID] = Self.installed(in: space)
        }
    }

    /// What the engine has installed in the Space's profile.
    private static func installed(in space: BrowserSpaceIdentity) -> [Installed] {
        guard ChromiumComposition.engineHost != nil, let pages = ChromiumComposition.chromiumEngine?.pages else {
            return []
        }
        return pages.request(InstalledExtensions(profileID: space.profileID)).extensions.map(Installed.init)
    }
    func load(_ space: BrowserSpaceIdentity, in browser: BrowserStore? = nil) async {
        guard authorized(space, in: browser), let engine = ChromiumComposition.chromiumEngine else { return }
        let ready = await engine.prepareProfile(space.profileID)
        guard ready, authorized(space, in: browser) else { return }
        installed[space.profileID] = Self.installed(in: space)
        revision &+= 1
    }
    func actions(for page: ChromiumNativePage) -> [BrowserExtensionActionPresentation] {
        _ = revision
        return page.extensions
    }
    /// The pinned actions of a Space's own toolbar row.
    ///
    /// The row belongs to the Space, so the pinned list comes from the Space's
    /// profile and is present whether or not a page is open. Where a page is
    /// open its per-tab state — badge, dynamic icon, whether a page action has
    /// anything to act on — is overlaid on top of it.
    func pinnedActions(
        for space: BrowserSpaceIdentity, page: ChromiumNativePage?
    ) -> [BrowserExtensionActionPresentation] {
        _ = revision
        guard ChromiumComposition.engineHost != nil, let pages = ChromiumComposition.chromiumEngine?.pages else {
            return []
        }
        let live = Dictionary(
            page?.extensions.map { ($0.id, $0) } ?? [],
            uniquingKeysWith: { first, _ in first })
        return pages.request(PinnedExtensions(profileID: space.profileID)).actions
            .map { action -> BrowserExtensionActionPresentation in
                if let tab = live[action.id] {
                    return BrowserExtensionActionPresentation(
                        id: tab.id, displayName: tab.displayName,
                        badgeText: tab.badgeText, icon: tab.icon, isPinned: true)
                }
                return BrowserExtensionActionPresentation(action)
            }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
    /// Runs a pinned action from a Space with no page open. Only an action with
    /// its own popup can run without one, so anything else states itself as
    /// unavailable rather than doing nothing.
    func runPinned(
        _ action: BrowserExtensionActionPresentation, space: BrowserSpaceIdentity,
        anchor: BrowserExtensionPopupAnchor?
    ) {
        let fallback = ChromiumComposition.activeNativeWindow
        let anchor =
            anchor
            ?? BrowserExtensionPopupAnchor(
                screenPoint: NSEvent.mouseLocation,
                sourceWindow: fallback)
        guard let host = ChromiumComposition.engineHost,
            let source = anchor.presentationSource(fallbackWindow: fallback),
            let windowID = source.view.window?.identifier.flatMap({ UUID(uuidString: $0.rawValue) }),
            host.runExtension(
                action.id, profile: space.profileID, window: windowID,
                anchorView: source.view, anchorRect: source.rect)
        else {
            ChromiumComposition.showNativeNotice(
                String(localized: "This extension action needs an open page."),
                icon: "puzzlepiece.extension")
            return
        }
    }
    /// Makes sure the Space's engine profile is loaded so its pinned list can be
    /// read before anything has been opened in it.
    ///
    /// Idempotent: the Space keeps whatever the engine reported, so the row can
    /// ask on every appearance and every Space change. A Space the window's own
    /// store does not own — a private window's, a borrowed workspace's — is left
    /// alone; its profile exists only while a page of its own does.
    func prepare(_ space: BrowserSpaceIdentity, in browser: BrowserStore? = nil) async {
        guard installed[space.profileID] == nil, authorized(space, in: browser) else { return }
        await load(space, in: browser)
    }
    /// Runs `command` for the extension `extensionID` names in `space`: opens
    /// the page it names in `window`, or makes its change and restates what
    /// the store lists. False when the Space is not one this window may
    /// change, or when the command has nothing to open and no change to make.
    @discardableResult
    func command(
        _ command: ExtensionCommand, extensionID: String = "", space: BrowserSpaceIdentity, window: NSWindow? = nil
    ) -> Bool {
        guard authorized(space), let pages = ChromiumComposition.chromiumEngine?.pages,
            let window = window ?? ChromiumComposition.activeNativeWindow
        else { return false }
        let options = installed[space.profileID]?.first { $0.id == extensionID }?.options
        if let destination = command.destination(extensionID, options), let url = URL(string: destination) {
            return ChromiumComposition.openExtensionURL(url, in: space, window: window)
        }
        guard let change = command.change else { return false }
        let accepted = pages.request(
            ChangeExtension(profileID: space.profileID, extensionID: extensionID, change: change))
        refresh()
        return accepted
    }
    func togglePin(_ action: BrowserExtensionActionPresentation, space: BrowserSpaceIdentity) {
        _ = command(action.isPinned ? .unpin : .pin, extensionID: action.id, space: space)
    }
    /// Reports the installed record backing an action so the menu can offer only
    /// the verbs the extension actually supports. The profile is already prepared
    /// whenever an action is presented, so the host answers synchronously.
    private func installedRecord(_ extensionID: String, in space: BrowserSpaceIdentity) -> Installed? {
        if let cached = installed[space.profileID] { return cached.first { $0.id == extensionID } }
        guard authorized(space) else { return nil }
        let items = Self.installed(in: space)
        guard !items.isEmpty else { return nil }
        installed[space.profileID] = items
        revision &+= 1
        return items.first { $0.id == extensionID }
    }
    /// - Parameter openSidePanel: Supplied only when the extension has a side
    ///   panel entry for the page the action was presented on. The caller owns
    ///   the window the panel would mount into, so it also owns the check.
    func presentMenu(
        _ action: BrowserExtensionActionPresentation, space: BrowserSpaceIdentity,
        anchor: BrowserExtensionPopupAnchor?, isPrivate: Bool = false,
        openSidePanel: (@MainActor () -> Void)? = nil
    ) {
        let menu = NSMenu(title: action.displayName)
        menu.autoenablesItems = false
        let handler = ExtensionMenuHandler()
        let record = installedRecord(action.id, in: space)
        if let openSidePanel {
            menu.addItem(handler.item(String(localized: "Open Side Panel")) { openSidePanel() })
            menu.addItem(.separator())
        }
        // A private window must never change the Space's persistent extension
        // state, so only the navigation verbs are offered from one.
        if !isPrivate {
            if record.map({ !$0.options.isEmpty && $0.enabled }) ?? true {
                menu.addItem(
                    handler.item(String(localized: "Extension Settings…")) { [weak self] in
                        self?.command(.options, extensionID: action.id, space: space)
                    })
            }
            menu.addItem(
                handler.item(
                    action.isPinned
                        ? String(localized: "Unpin from Toolbar") : String(localized: "Pin to Toolbar")
                ) { [weak self] in
                    self?.togglePin(action, space: space)
                })
            if let record {
                menu.addItem(
                    handler.item(
                        record.enabled
                            ? String(localized: "Disable Extension") : String(localized: "Enable Extension")
                    ) { [weak self] in
                        self?.command(record.enabled ? .disable : .enable, extensionID: action.id, space: space)
                    })
            }
            menu.addItem(.separator())
        }
        menu.addItem(
            handler.item(String(localized: "Manage Extension…")) { [weak self] in
                self?.command(.details, extensionID: action.id, space: space)
            })
        menu.addItem(
            handler.item(String(localized: "Manage Extensions…")) { [weak self] in
                self?.command(.manage, space: space)
            })
        if record?.webStore ?? false {
            menu.addItem(
                handler.item(String(localized: "View on Chrome Web Store")) { [weak self] in
                    self?.command(.store, extensionID: action.id, space: space)
                })
        }
        if !isPrivate, let record {
            menu.addItem(.separator())
            menu.addItem(
                handler.item(String(localized: "Remove Extension…")) { [weak self] in
                    self?.confirmRemoval(record, space: space)
                })
        }
        if let source = anchor?.presentationSource(fallbackWindow: ChromiumComposition.activeNativeWindow) {
            menu.popUp(positioning: nil, at: NSPoint(x: source.rect.minX, y: source.rect.minY), in: source.view)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
        withExtendedLifetime(handler) {}
    }
    /// Removal asked for by identifier — the Chrome Web Store listing for an
    /// extension already installed in this Space. The confirmation, the Space's
    /// ownership check and the engine command are the menu's own.
    func confirmRemoval(
        _ extensionID: String, in space: BrowserSpaceIdentity,
        completion: (@MainActor () -> Void)? = nil
    ) {
        guard let record = installedRecord(extensionID, in: space) else {
            completion?()
            return
        }
        confirmRemoval(record, space: space, completion: completion)
    }
    /// Mirrors the confirmation the extension settings pane requires before an
    /// uninstall. The menu's tracking loop owns the event while an item runs, so
    /// the alert is presented once the menu has dismissed.
    private func confirmRemoval(
        _ record: Installed, space: BrowserSpaceIdentity,
        completion: (@MainActor () -> Void)? = nil
    ) {
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.authorized(space) else {
                completion?()
                return
            }
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = String(localized: "Remove \(record.name)?")
            alert.informativeText = String(
                localized:
                    "\(record.name) and its Space-local data will be removed. Other Spaces are unchanged.")
            alert.addButton(withTitle: String(localized: "Remove from \(space.name)"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            alert.buttons.first?.hasDestructiveAction = true
            let complete: (NSApplication.ModalResponse) -> Void = { response in
                MainActor.assumeIsolated {
                    defer { completion?() }
                    guard response == .alertFirstButtonReturn else { return }
                    guard self.command(.remove, extensionID: record.id, space: space) else {
                        self.reportFailure()
                        return
                    }
                }
            }
            if let window = ChromiumComposition.activeNativeWindow {
                alert.beginSheetModal(for: window, completionHandler: complete)
            } else {
                complete(alert.runModal())
            }
        }
    }
    private func reportFailure() {
        BrowserNoticeCenter.shared.post(
            BrowserNotice(
                message: String(
                    localized:
                        "Couldn’t complete that extension action. Check its details for policy or permission requirements."
                ),
                systemImage: "exclamationmark.triangle"))
    }
    func install(
        _ id: String, in space: BrowserSpaceIdentity, anchor: NSView?, copies: Set<UUID> = [],
        completion: (@MainActor () -> Void)? = nil
    ) {
        guard installation == nil, authorized(space),
            let window = anchor?.window ?? ChromiumComposition.activeNativeWindow
        else {
            completion?()
            return
        }
        installCompletion = completion
        let job = ChromiumExtensionInstallation(id: id, space: space, window: window, store: self)
        job.selectedSpaces = copies
        installation = job
        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.contentViewController = NSHostingController(rootView: BrowserChromeWebStoreInstallView(model: job))
        self.popover = popover
        // Anchor native presentation in Crest's hosting view. Anchoring it in
        // Chromium's responder subtree lets web focus consume popover input.
        guard let source = window.contentView else {
            dismissInstallation()
            return
        }
        // AppKit reads a caller's positioning rectangle as if the view were not
        // flipped, and SwiftUI's hosting view is flipped: a rectangle measured
        // from its top edge presented the review past the window's lower edge
        // and off the screen. A one-point positioning view carries the anchor
        // instead, because a subview's own frame is resolved in its superview's
        // coordinate space whichever way that space runs.
        let spot = NSView(
            frame: NSRect(
                x: min(160, source.bounds.width / 2),
                y: source.isFlipped ? 44 : source.bounds.height - 44, width: 1, height: 1))
        source.addSubview(spot)
        anchorSpot = spot
        popover.show(relativeTo: .zero, of: spot, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        windowClosed = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismissInstallation() }
        }
        Task { await job.start() }
    }
    /// The engine asks whether to install the package the install operation of
    /// the window `asked` names verified.
    func review(_ asked: ExtensionInstallAsked, reply: @escaping (Bool, Bool) -> Void) {
        let review = asked.question
        guard let job = installation, job.window?.identifier?.rawValue == asked.windowID.uuidString,
            review.extensionID == job.id
        else {
            // No user-owned install operation may inherit an unrelated consent.
            reply(false, false)
            return
        }
        job.review(review, reply: reply)
    }
    func dismissInstallation() {
        installation?.cancel()
        installation = nil
        popover?.close()
        popover = nil
        if let windowClosed { NotificationCenter.default.removeObserver(windowClosed) }
        windowClosed = nil
        anchorSpot?.removeFromSuperview()
        anchorSpot = nil
        let completion = installCompletion
        installCompletion = nil
        completion?()
    }
}

/// Owns the menu item closures; `NSMenuItem.target` is weak, so this has to
/// outlive the menu's tracking loop.
@MainActor private final class ExtensionMenuHandler: NSObject {
    private var handlers: [() -> Void] = []
    func item(_ title: String, perform: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(invoke(_:)), keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        item.tag = handlers.count
        handlers.append(perform)
        return item
    }
    @objc private func invoke(_ sender: NSMenuItem) {
        guard handlers.indices.contains(sender.tag) else { return }
        handlers[sender.tag]()
    }
}

@Observable @MainActor
final class ChromiumExtensionInstallation {
    let id: String
    let space: BrowserSpaceIdentity
    weak var window: NSWindow?
    private let store: ChromiumExtensionStore
    /// The verified package the core asks the person about, as its question
    /// presents it.
    var question: ExtensionInstallQuestion?
    /// The name the review shows: the package's own, or its identifier when
    /// it names none.
    var questionName: String? { question.map { $0.name.isEmpty ? $0.extensionID : $0.name } }
    var questionIcon: NSImage? { question?.icon.flatMap(NSImage.init(data:)) }
    var selectedSpaces: Set<UUID> = []
    var withhold = false
    var canWithhold = false
    var preparing = true
    /// The fraction of the package received, once its download knows its size.
    var downloaded: Double?
    /// Set while the package has shown no progress and the engine is still
    /// starting up: the second download has begun or has failed, and the first
    /// has not yet said anything.
    var waitingOnEngine = false
    var installing = false
    var completed = false
    var installedCount = 0
    var failure: String?
    var canAccept = false
    @ObservationIgnored private var consent: ((Bool, Bool) -> Void)?
    @ObservationIgnored private var approvedIdentity: [String]?
    @ObservationIgnored private var approvedDestinations: [BrowserSpaceIdentity] = []
    @ObservationIgnored private var package: URL?
    /// The package download while it runs, so closing the review stops it.
    @ObservationIgnored private var transfer: (any CrestExtensionDownload)?
    @ObservationIgnored private var canceled = false
    @ObservationIgnored private var targetSpace: BrowserSpaceIdentity?
    /// The race between the two package downloads while one is running.
    @ObservationIgnored private var packageRace: ExtensionPackageRace?
    @ObservationIgnored private var downloadStarted = ContinuousClock.now
    /// When either download last reported progress, on the clock that stops while the Mac sleeps.
    @ObservationIgnored private var lastProgress = SuspendingClock.now
    /// Starts the second download after a quiet engine, and ends the race at
    /// its ceiling.
    @ObservationIgnored private var raceTimers: Task<Void, Never>?
    @ObservationIgnored private var fallbackSession: URLSession?
    @ObservationIgnored private var fallbackTask: URLSessionDownloadTask?
    @ObservationIgnored private var fallbackProgress: NSKeyValueObservation?
    /// Stops the Web Store download that grows past the size an extension
    /// package can have, instead of letting it fill the disk until it ends.
    @ObservationIgnored private var fallbackSize: NSKeyValueObservation?
    /// What each download has reported, kept apart so a failed download's
    /// progress does not stay on the bar. The bar shows the larger of the two.
    @ObservationIgnored private var engineFraction: Double?
    @ObservationIgnored private var fallbackFraction: Double?
    /// Whether the Web Store download is running, so progress it reported just
    /// before it failed is not shown after.
    @ObservationIgnored private var fallbackRunning = false

    init(id: String, space: BrowserSpaceIdentity, window: NSWindow, store: ChromiumExtensionStore) {
        self.id = id
        self.space = space
        self.window = window
        self.store = store
    }
    var isAuthorized: Bool { store.authorized(space) && (targetSpace.map { store.authorized($0) } ?? true) }
    var destinations: [BrowserSpaceIdentity] {
        store.spaces.filter { $0.id != space.id && !(store.installed[$0.profileID] ?? []).contains { $0.id == id } }
    }
    func start() async {
        for target in store.spaces { await store.load(target) }
        guard !canceled else { return }
        do {
            let retained = try await download()
            package = retained
            defer {
                try? FileManager.default.removeItem(at: retained)
                package = nil
            }
            guard !canceled else { return }
            try await installPackage(in: space)
            installedCount = 1
            // Freeze the explicitly reviewed targets and package; every copy is
            // independently verified by Chromium and keeps its own profile data.
            for target in approvedDestinations {
                guard !canceled else { return }
                try await installPackage(in: target)
                installedCount += 1
            }
            completed = true
            store.refresh()
        } catch {
            if !canceled { failure = error.localizedDescription }
        }
        preparing = false
        installing = false
    }
    /// The package as the Space's own engine profile downloads it; Chromium's
    /// installer then judges it for every Space it is installed in.
    ///
    /// The engine's download is the one that runs. It can stay silent for
    /// minutes when no page has loaded since the browser started, so when it
    /// has reported nothing after `fallbackDelay` the same package is also
    /// fetched from the Web Store directly, and the first to deliver wins. The
    /// package still goes through the engine's own verification and consent.
    private func download() async throws -> URL {
        guard let host = ChromiumComposition.engineHost, !canceled else { throw URLError(.cancelled) }
        let race = ExtensionPackageRace()
        packageRace = race
        engineFraction = nil
        fallbackFraction = nil
        fallbackRunning = false
        downloaded = nil
        waitingOnEngine = false
        downloadStarted = ContinuousClock.now
        // The timers count time the Mac is awake: a sleep is not a slow download.
        let started = SuspendingClock.now
        lastProgress = started
        // Engine callbacks are built outside the actor, so they may arrive on any thread.
        let progress: @Sendable (Double) -> Void = { [weak self] fraction in
            race.engineReportedProgress()
            Task { @MainActor in self?.received(fraction, from: .engine) }
        }
        let completion: @Sendable (String?, String) -> Void = { [weak self] package, message in
            race.engineFinished(package: package, message: message)
            if package == nil { Task { @MainActor in self?.engineDidFail() } }
        }
        transfer = host.downloadExtension(id, profile: space.profileID, progress: progress, completion: completion)
        if transfer == nil { race.engineFinished(package: nil, message: "", unavailable: true) }
        raceTimers = Task { @MainActor [weak self] in
            try? await Task.sleep(until: started.advanced(by: Self.fallbackDelay), clock: .suspending)
            guard !Task.isCancelled else { return }
            self?.startFallback(race, host: host)
            // A download that is still making progress is never cut off, however long it takes:
            // only one that has been silent for the whole of `silenceLimit` is given up on.
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(until: self.lastProgress.advanced(by: Self.silenceLimit), clock: .suspending)
                guard !Task.isCancelled else { return }
                guard self.lastProgress.advanced(by: Self.silenceLimit) <= SuspendingClock.now else { continue }
                race.abort(
                    NSError(
                        domain: "CrestExtension", code: 3,
                        userInfo: [
                            NSLocalizedDescriptionKey: String(
                                localized: "This extension stopped downloading. Check your connection and try again.")
                        ]))
                return
            }
        }
        defer { endRace() }
        let won = try await race.wait()
        return won.package
    }
    /// Quiet for this long, the engine's download is joined by a second one.
    private static let fallbackDelay = Duration.seconds(5)
    /// A download that reports no progress for this long is given up on. It is longer than the
    /// browser engine's startup hold (about three minutes), which the engine's own download waits out.
    private static let silenceLimit = Duration.seconds(240)

    /// Begins the Web Store download, unless the race is already decided, the
    /// engine has spoken, or the identifier is not one the store can name.
    private func startFallback(_ race: ExtensionPackageRace, host: any CrestMacShell) {
        guard packageRace === race, !canceled,
            let url = ExtensionFallbackDownload.url(id: id, engineVersion: host.engineVersion()),
            race.beginFallback()
        else { return }
        fallbackRunning = true
        waitingOnEngine = downloaded == nil
        let session = ExtensionFallbackDownload.makeSession()
        let cutoff = ExtensionFallbackDownload.Cutoff()
        let task = session.downloadTask(with: ExtensionFallbackDownload.request(for: url)) {
            [weak self] location, response, error in
            switch ExtensionFallbackDownload.ownedPackage(
                location: location, response: response, error: error, oversized: cutoff.isSet)
            {
            case .success(let package):
                // A late success is deleted by the race if it lost.
                _ = race.offer(package, from: .urlSession)
            case .failure(let failure):
                if race.fallbackFailed(failure.reason) {
                    Task { @MainActor in self?.fallbackDidFail(failure.reason) }
                }
            }
        }
        fallbackSession = session
        fallbackTask = task
        fallbackProgress = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            guard progress.totalUnitCount > 0 else { return }
            let fraction = progress.fractionCompleted
            Task { @MainActor in self?.received(fraction, from: .urlSession) }
        }
        fallbackSize = task.observe(\.countOfBytesReceived) { [weak task] observed, _ in
            guard
                observed.countOfBytesReceived > ExtensionFallbackDownload.sizeCap
                    || observed.countOfBytesExpectedToReceive > ExtensionFallbackDownload.sizeCap
            else { return }
            cutoff.set()
            task?.cancel()
        }
        task.resume()
    }
    private func fallbackDidFail(_ reason: String) {
        guard packageRace != nil else { return }
        fallbackProgress = nil
        fallbackSize = nil
        fallbackRunning = false
        // Progress that came only from the failed download is no longer true.
        fallbackFraction = nil
        showProgress()
        waitingOnEngine = downloaded == nil
    }
    /// The engine's own download has failed while the Web Store download is
    /// still the one that can deliver, so the engine is no longer what is awaited.
    private func engineDidFail() {
        guard packageRace != nil else { return }
        waitingOnEngine = false
    }
    private func received(_ fraction: Double, from source: ExtensionPackageRace.Source) {
        guard packageRace != nil else { return }
        switch source {
        case .engine:
            engineFraction = max(engineFraction ?? 0, fraction)
        case .urlSession:
            guard fallbackRunning else { return }
            fallbackFraction = max(fallbackFraction ?? 0, fraction)
        }
        showProgress()
        lastProgress = SuspendingClock.now
        waitingOnEngine = false
    }
    private func showProgress() {
        downloaded = [engineFraction, fallbackFraction].compactMap { $0 }.max()
    }
    /// Stops whatever of the race is still running. The loser of a decided
    /// race is canceled here, and its package, if one arrives late, is deleted
    /// by the race.
    private func endRace() {
        raceTimers?.cancel()
        raceTimers = nil
        transfer?.cancel()
        transfer = nil
        fallbackTask?.cancel()
        fallbackSession?.invalidateAndCancel()
        fallbackTask = nil
        fallbackSession = nil
        fallbackProgress = nil
        fallbackSize = nil
        fallbackRunning = false
        // The race is over, so nothing is waited on any more, whoever won.
        waitingOnEngine = false
        packageRace = nil
    }
    private func installPackage(in target: BrowserSpaceIdentity) async throws {
        guard !canceled, store.authorized(target), let package, let host = ChromiumComposition.engineHost,
            let windowID = window?.identifier.flatMap({ UUID(uuidString: $0.rawValue) })
        else { throw URLError(.cancelled) }
        targetSpace = target
        let staged = FileManager.default.temporaryDirectory.appendingPathComponent("crest-extension-\(UUID()).crx")
        try FileManager.default.copyItem(at: package, to: staged)
        defer { try? FileManager.default.removeItem(at: staged) }
        let result: (Bool, String) = await withCheckedContinuation { continuation in
            if !host.installExtension(
                id, package: staged.path, profile: target.profileID, window: windowID,
                completion: { success, message in
                    continuation.resume(returning: (success, message))
                })
            {
                continuation.resume(returning: (false, "The Space is no longer available."))
            }
        }
        guard result.0 else {
            throw NSError(
                domain: "CrestExtension", code: 1,
                userInfo: [NSLocalizedDescriptionKey: result.1.isEmpty ? "Installation canceled." : result.1])
        }
    }
    func review(_ review: ExtensionInstallQuestion, reply: @escaping (Bool, Bool) -> Void) {
        guard !canceled, store.authorized(space), let targetSpace, store.authorized(targetSpace) else {
            reply(false, false)
            return
        }
        if let approvedIdentity {
            // Consent applies only to the same verified package and warnings.
            reply(Self.consentIdentity(of: review) == approvedIdentity, withhold)
            return
        }
        question = review
        canWithhold = review.canWithholdSiteAccess
        withhold = review.withholdsSiteAccess
        consent = reply
        preparing = false
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.canAccept = true
        }
    }
    func accept() {
        guard canAccept, let question, store.authorized(space), let consent else { return }
        approvedIdentity = Self.consentIdentity(of: question)
        approvedDestinations = destinations.filter { selectedSpaces.contains($0.id) }
        self.consent = nil
        installing = true
        consent(true, withhold)
    }
    func cancel() {
        canceled = true
        // The download then fails, which a canceled review ignores.
        packageRace?.abort(URLError(.cancelled))
        endRace()
        let callback = consent
        consent = nil
        callback?(false, false)
    }
    func dismiss() { store.dismissInstallation() }

    /// What a consent covers: the same verified package, at the same version,
    /// asking for the same access.
    private static func consentIdentity(of question: ExtensionInstallQuestion) -> [String] {
        [question.extensionID, question.version] + question.permissions.sorted()
    }
}
