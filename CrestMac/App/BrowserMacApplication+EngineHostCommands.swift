import Foundation

/// The engine's requests run the operations Crest's own menus, Settings
/// presentation and external-link handling run for the same request.
extension BrowserMacApplication: BrowserEngineHostCommands {
    // MARK: - Types

    /// The stores one window presents.
    private struct HostWindow {
        let browser: BrowserStore
        let pages: BrowserPagePool
        let chrome: BrowserChromeState
        let settings: BrowserSpaceSettingsPresentationState
        let windowState: BrowserWindowStateStore?
    }

    // MARK: - Variables

    /// The Spaces the engine's extensions may act in: every one this window
    /// family holds that is neither locked nor being deleted.
    var extensionSpaces: [BrowserSpaceIdentity] {
        browser.spaceModels.filter {
            !browser.deletingSpaceIDs.contains($0.id) && !spaceAccess.isLocked($0)
        }.map(\.identity)
    }

    // MARK: - Actions - Spaces

    func extensionSpace(forProfile profileID: UUID) -> BrowserSpaceIdentity? {
        extensionSpaces.first { $0.profileID == profileID }
    }

    func selectSpace(_ spaceID: SpaceID, in window: BrowserWindowID) {
        hostWindow(window)?.browser.selectSpace(spaceID)
    }

    // MARK: - Actions - Tabs

    @discardableResult
    func openTab(_ url: URL, in space: BrowserSpaceRuntimeAssignment, window: BrowserWindowID) -> Bool {
        guard let host = hostWindow(window), let target = host.browser.spaceModel(matching: space),
            !spaceAccess.isLocked(target)
        else { return false }
        host.browser.selectSpace(target.id)
        guard host.browser.openNewTab(url: url, matching: space) != nil else { return false }
        host.pages.select()
        return true
    }

    @discardableResult
    func openExternalLink(_ url: URL, in space: BrowserSpaceRuntimeAssignment, window: BrowserWindowID) -> Bool {
        guard let host = hostWindow(window), host.browser.openNewTab(url: url, matching: space) != nil
        else { return false }
        host.pages.select()
        host.pages.navigate(to: url.absoluteString)
        host.chrome.dismissCommandPalette()
        return true
    }

    func openSettings(in window: BrowserWindowID) {
        guard let host = hostWindow(window) else { return }
        host.browser.openSettings()
        host.pages.select()
    }

    func openExtensionSettings(for space: BrowserSpaceRuntimeAssignment, in window: BrowserWindowID) {
        guard let host = hostWindow(window) else { return }
        host.settings.present(.extensions, assignment: space)
        host.browser.openSettings()
        host.pages.select()
    }

    func openGettingStarted(in window: BrowserWindowID) {
        guard let host = hostWindow(window) else { return }
        host.browser.openGettingStarted()
        host.pages.select()
    }

    // MARK: - Actions - Lifecycle

    func flushPendingPersistenceBeforeQuit() async {
        // Private and temporary windows keep nothing, and every other window
        // shares the persistent session, so one flush covers the edits of all.
        let pools = [pages] + windowCoordinator.openWindowPages
        // Reading each resident page's session state has to happen while the
        // pages are still resident.
        for pool in pools { pool.archiveResidentTabStates() }
        await BrowserPersistenceFlush().run { [browser] in
            await browser.flushPendingSyncPersistenceUntilSettled()
            for pool in pools { await pool.flushPendingTabStateWrites() }
        }
    }

    func closePrivateBrowsing() {
        closePrivateBrowsingWindow()
    }

    // MARK: - Mutators

    private func hostWindow(_ id: BrowserWindowID) -> HostWindow? {
        if id == privatePages.windowID {
            return HostWindow(
                browser: privateBrowser, pages: privatePages, chrome: privateChrome,
                settings: spaceSettingsPresentation, windowState: nil)
        }
        guard let model = windowCoordinator.existingModel(for: id) else { return nil }
        return HostWindow(
            browser: model.browser, pages: model.pages, chrome: model.chrome,
            settings: model.spaceSettingsPresentation, windowState: model.windowState)
    }
}
