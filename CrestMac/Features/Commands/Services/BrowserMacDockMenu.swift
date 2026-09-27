import AppKit
import SwiftUI

/// The Dock icon's menu, as the core answers it: Crest's window commands,
/// then the Spaces a window can show, each drawn as the Space switcher draws
/// it and checked when the frontmost window shows it. macOS adds the window
/// list and its own items around it.
///
/// A command runs as the menu bar runs it, from the window the core names. A
/// Space shows in that window, which is never a private one, or opens a
/// window on itself when the core names none; a locked Space shows locked
/// there, where the person unlocks it as they would anywhere else.
@MainActor
final class BrowserMacDockMenu: NSObject {
    // MARK: - Types

    /// Hands the Dock menu the action that opens a SwiftUI composition's
    /// scenes. AppKit asks the application delegate for the menu outside any
    /// view, so the composition's windows supply it as they appear.
    struct SceneOpening: ViewModifier {
        let dockMenu: BrowserMacDockMenu
        @Environment(\.openWindow) private var openWindow

        func body(content: Content) -> some View {
            content.onAppear { dockMenu.openWindow = openWindow }
        }
    }

    /// A command chosen from the menu, and the window it acts from.
    private struct CommandChoice {
        let command: DockMenuCommand
        let windowID: UUID?
    }

    /// A Space chosen from the menu, and the window it shows in.
    private struct SpaceChoice {
        let space: DockMenuSpace
        let windowID: UUID?
    }

    // MARK: - Variables

    private unowned let application: BrowserMacApplication
    /// Opens the scenes of a composition whose windows SwiftUI presents. One
    /// that presents its own (`BrowserMacWindowPresentation.host`) never
    /// calls it.
    fileprivate(set) var openWindow = EnvironmentValues().openWindow

    /// The browser windows, frontmost first, by the identity each has in the
    /// core: the order AppKit stacks them in, then any it leaves out, such as
    /// a minimized one.
    private var stackedWindowIDs: [UUID] {
        let pools = [application.privatePages] + application.windowCoordinator.openWindowPages
        let windows = pools.compactMap { pool in pool.presentationWindow.map { (window: $0, id: pool.windowID) } }
        let stacked = NSApp.orderedWindows.compactMap { window in windows.first { $0.window === window }?.id }
        return stacked + windows.map(\.id).filter { !stacked.contains($0) }
    }

    // MARK: - Initializers

    init(application: BrowserMacApplication) {
        self.application = application
    }

    // MARK: - Actions - Menu

    /// The menu the Dock shows now, or nil when the core cannot answer.
    func menu() -> NSMenu? {
        guard let content = try? application.browser.core.query(DockMenu(windowIDs: stackedWindowIDs)) else {
            return nil
        }
        let menu = NSMenu()
        for command in content.commands {
            let item = NSMenuItem(
                title: String(localized: command.title), action: #selector(runCommand(_:)), keyEquivalent: "")
            item.image = NSImage(systemSymbolName: command.command.symbol, accessibilityDescription: nil)
            item.representedObject = CommandChoice(command: command, windowID: content.windowID)
            item.target = self
            menu.addItem(item)
        }
        if !content.spaces.isEmpty { menu.addItem(.separator()) }
        for space in content.spaces {
            let item = NSMenuItem(title: space.name, action: #selector(showSpace(_:)), keyEquivalent: "")
            item.image = BrowserSpaceSymbolArtworkRenderer.shared.menuImage(for: BrowserSpaceIdentity(dockSpace: space))
            item.state = space.isShown ? .on : .off
            item.representedObject = SpaceChoice(space: space, windowID: content.windowID)
            item.target = self
            menu.addItem(item)
        }
        return menu
    }

    // MARK: - Actions - Choices

    @objc private func runCommand(_ item: NSMenuItem) {
        guard let choice = item.representedObject as? CommandChoice else { return }
        NSApp.activate()
        actions(from: choice.windowID).perform(choice.command.command)
    }

    @objc private func showSpace(_ item: NSMenuItem) {
        guard let choice = item.representedObject as? SpaceChoice else { return }
        NSApp.activate()
        if let windowID = choice.windowID, let model = application.windowCoordinator.existingModel(for: windowID) {
            actions(from: windowID).selectSpace(choice.space.spaceID)
            if let window = model.window {
                if window.isMiniaturized { window.deminiaturize(nil) }
                window.makeKeyAndOrderFront(nil)
            }
            return
        }
        // No window can show the Space, so the person asked for one.
        let request = BrowserMacWindowRequest.normal(sourceWindowID: nil)
        guard let model = application.windowCoordinator.model(for: request) else { return }
        model.browser.selectSpace(choice.space.spaceID)
        if let host = BrowserMacWindowPresentation.host {
            host.openWindow(request)
        } else {
            openWindow(id: BrowserSceneID.browser.rawValue, value: request)
        }
    }

    /// The menu bar's commands as they run in the window `windowID`, or as
    /// they run with no window focused when it is nil.
    private func actions(from windowID: UUID?) -> BrowserCommandActions {
        if let windowID, let model = application.windowCoordinator.existingModel(for: windowID) {
            return BrowserCommandActions(
                browser: model.browser, pages: model.pages, chrome: model.chrome, openWindow: openWindow,
                spaceAccess: application.spaceAccess, targetWindowID: windowID)
        }
        return BrowserCommandActions(
            browser: application.browser, pages: application.pages, chrome: application.chrome,
            openWindow: openWindow, spaceAccess: application.spaceAccess)
    }
}
