import AppKit

extension BrowserMacShell {
    // MARK: - Variables

    /// The menu bar's commands as they run in the key browser window.
    var activeActions: BrowserCommandActions? {
        windows?.activeActions
    }

    /// Whether the application can check for updates, which an isolated
    /// launch without an update feed cannot.
    var canCheckForUpdates: Bool {
        application?.softwareUpdates.isEnabled == true
    }

    // MARK: - Actions - Shortcuts

    /// Runs the Crest command `event`'s chord is bound to, before the view
    /// that has focus sees it; a chord no command claims goes to the engine
    /// for the active page. Answers whether it was taken. An engine whose
    /// views take key equivalents before the menu bar does calls this for
    /// every key down, so Crest's shortcuts win over web content.
    func handleShortcut(_ event: NSEvent) -> Bool {
        guard let windows, let application, event.type == .keyDown,
            NSApp.modalWindow == nil, NSApp.keyWindow?.attachedSheet == nil,
            (NSApp.keyWindow?.firstResponder as? ShortcutRecorderButton)?.isRecording != true,
            let shortcut = BrowserShortcut(event: event), shortcut.isValid
        else { return false }
        if shortcut == BrowserShortcut(key: .character("q"), modifiers: .command) {
            NSApp.terminate(nil)
            return true
        }
        guard !isQuitting else { return true }
        if shortcut == BrowserShortcut(key: .character(","), modifiers: .command) {
            BrowserMacApplicationAction.settings.perform(in: self)
            return true
        }
        // Inspector, extension popup and system dialog responders are not a
        // browser workspace. Their editing and close shortcuts stay local.
        let context = windows.activeContext
        guard context != nil || windows.isQuickWindowKey else { return false }
        if let command = application.shortcuts.command(for: event, isEnabled: canPerform) {
            perform(command)
            return true
        }
        // Crest's own shortcuts win. What is left can belong to the engine,
        // such as an extension's binding in the active page's Space.
        guard let page = context?.pages.activePage else { return false }
        return engineHost.handleUnclaimedShortcut(event, page: page)
    }

    // MARK: - Actions - Commands

    /// Whether `command` can run now: never while a quit is prepared or a
    /// modal window or sheet is up, and otherwise as the key window's own
    /// commands say. A new window needs no window, and any window the shell
    /// opened, such as a Quick Window or setup, can close itself.
    func canPerform(_ command: ShortcutCommand) -> Bool {
        guard !isQuitting, NSApp.modalWindow == nil, NSApp.keyWindow?.attachedSheet == nil else { return false }
        switch command.kind {
        case .newWindow, .newPrivateWindow: return true
        case .closeWindow, .closeTabOrWindow: return activeActions != nil || windows?.isShellWindowKey == true
        default: return activeActions?.canPerform(command) == true
        }
    }

    /// Runs `command` in the key browser window, or with none, the commands
    /// that need no window.
    func perform(_ command: ShortcutCommand) {
        guard canPerform(command) else { return }
        if let actions = activeActions {
            actions.perform(command)
            return
        }
        switch command.kind {
        case .newWindow: windows?.open(.normal(sourceWindowID: nil), activation: .key)
        case .newPrivateWindow: windows?.openPrivateWindow()
        case .closeWindow, .closeTabOrWindow: NSApp.keyWindow?.performClose(nil)
        default: break
        }
    }

    // MARK: - Actions - Engine window requests

    /// Focuses the key window's location field.
    func focusLocation() {
        activeActions?.openLocation()
    }

    /// Crest keeps a page by pinning its tab.
    func bookmarkActivePage() {
        activeActions?.toggleSelectedTabPinned()
    }

    /// Shows the key window's launcher, which searches its tabs.
    func showTabSearch() {
        windows?.activeContext?.chrome.presentCommandPalette()
    }

    // MARK: - Actions - Application

    /// The standard About panel, crediting the engine that owns the process.
    func showAbout() {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: ProductIdentity.name,
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? "",
            .applicationIcon: NSApp.applicationIconImage as Any,
        ]
        if let credits = engineHost.aboutCredits { options[.credits] = NSAttributedString(string: credits) }
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    func checkForUpdates() {
        application?.softwareUpdates.checkForUpdates()
    }

    /// Opens Settings in the key browser window, opening one when none is key.
    func openSettings() {
        guard let context = activeContextOpeningWindow() else { return }
        application?.openSettings(in: context.windowID)
    }

    /// Opens Getting Started in the key browser window, opening one when none
    /// is key.
    func openGettingStarted() {
        guard let context = activeContextOpeningWindow() else { return }
        application?.openGettingStarted(in: context.windowID)
    }

    /// The key browser window's stores, after opening a window when none is key.
    private func activeContextOpeningWindow() -> BrowserMacWindowContext? {
        guard let windows else { return nil }
        if windows.activeContext == nil { windows.open(.normal(sourceWindowID: nil), activation: .key) }
        return windows.activeContext
    }
}
