import AppKit
import Foundation

/// Crest-owned actions placed ahead of an engine's page menu. Engines keep
/// their own editing and extension rows; these actions use Crest's Space and
/// tab routing after the menu closes.
struct BrowserPageContextMenuAction {
    // MARK: - Types

    /// What the row does, with what it does it to.
    enum Kind: Equatable {
        case search
        case peek
        case split
        case space(UUID)
    }

    // MARK: - Variables

    let kind: Kind
    let title: String
    let symbolName: String
    let linkURL: URL?
    let selectionText: String?
    /// The Space a Space destination opens the link in, whose icon its row
    /// shows; nil for every other row.
    var space: BrowserSpaceIdentity?

    var isSpaceDestination: Bool {
        if case .space = kind { return true }
        return false
    }
}

/// A page that puts Crest's rows in an engine's context menu and runs the one
/// the person picks.
@MainActor
protocol BrowserPageContextMenuHost: AnyObject {
    func contextMenuActions(linkURL: URL?, selectionText: String?) -> [BrowserPageContextMenuAction]
    @discardableResult func performContextMenuAction(_ action: BrowserPageContextMenuAction) -> Bool
}

/// Crest's rows in an engine's context menu for one page: the other Spaces a
/// link opens in grouped under one row, then the page's own rows, ahead of the
/// engine's rows. A row runs only while the page's view is still in the window
/// the menu opened in.
@MainActor
struct BrowserPageContextMenu {
    // MARK: - Types

    /// One row's action, which its menu item keeps and runs.
    @MainActor
    private final class Row: NSObject {
        let action: BrowserPageContextMenuAction
        weak var host: (any BrowserPageContextMenuHost)?
        weak var view: NSView?
        let windowNumber: Int?

        init(_ action: BrowserPageContextMenuAction, host: any BrowserPageContextMenuHost, view: NSView) {
            self.action = action
            self.host = host
            self.view = view
            windowNumber = view.window?.windowNumber
        }

        /// Runs the row on the main queue's next turn, once the engine's menu
        /// and the engine code that showed it have returned, while the page's
        /// view is still in the window the menu opened in.
        ///
        /// The Objective-C name is spelled out: a method named `perform(_:)`
        /// makes `#selector` pick NSObject's `performSelector:`, which sends
        /// the menu item itself as a selector and raises.
        @objc(runContextMenuRow:) func run(_ sender: NSMenuItem) {
            Task { @MainActor in
                guard let view, view.window?.windowNumber == windowNumber else { return }
                host?.performContextMenuAction(action)
            }
        }
    }

    // MARK: - Variables

    let actions: [BrowserPageContextMenuAction]
    let host: any BrowserPageContextMenuHost
    /// The page's view, whose window the menu opened in.
    let view: NSView

    // MARK: - Actions - Menu

    /// Puts the rows ahead of what `menu` holds, with a separator between.
    func insert(into menu: NSMenu) {
        guard !actions.isEmpty else { return }
        var items: [NSMenuItem] = []
        let spaceActions = actions.filter(\.isSpaceDestination)
        if !spaceActions.isEmpty {
            let group = NSMenuItem(
                title: String(localized: "Open Link in Another Space"), action: nil, keyEquivalent: "")
            group.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: nil)
            let submenu = NSMenu()
            for action in spaceActions { submenu.addItem(item(for: action)) }
            group.submenu = submenu
            items.append(group)
        }
        items.append(contentsOf: actions.filter { !$0.isSpaceDestination }.map(item(for:)))
        for (index, item) in items.enumerated() { menu.insertItem(item, at: index) }
        if menu.items.count > items.count { menu.insertItem(.separator(), at: items.count) }
    }

    private func item(for action: BrowserPageContextMenuAction) -> NSMenuItem {
        let row = Row(action, host: host, view: view)
        let item = NSMenuItem(title: action.title, action: #selector(Row.run(_:)), keyEquivalent: "")
        item.target = row
        // The menu item keeps its row alive.
        item.representedObject = row
        item.image =
            action.space.flatMap { BrowserSpaceSymbolArtworkRenderer.shared.menuImage(for: $0) }
            ?? NSImage(systemSymbolName: action.symbolName, accessibilityDescription: nil)
        return item
    }
}

extension BrowserPage: BrowserPageContextMenuHost {
    func contextMenuActions(linkURL: URL?, selectionText: String?) -> [BrowserPageContextMenuAction] {
        guard let context = navigationContext else { return [] }
        let source = BrowserTabRuntimeAssignment(
            tabID: context.tabID, spaceID: context.spaceID,
            profileID: context.assignment.profileID)
        var actions: [BrowserPageContextMenuAction] = []

        if let linkURL, BrowserCorePolicy.acceptsExternalURL(linkURL),
            linkDestinationHost.canOpenLink(from: source)
        {
            for space in linkDestinationHost.otherSpaces(from: source) {
                actions.append(
                    BrowserPageContextMenuAction(
                        kind: .space(space.id), title: space.settings.name,
                        symbolName: "square.stack.3d.up", linkURL: linkURL, selectionText: nil,
                        space: space.identity))
            }
            actions.append(
                BrowserPageContextMenuAction(
                    kind: .peek, title: String(localized: "Open Link in Peek"),
                    symbolName: "rectangle.on.rectangle", linkURL: linkURL, selectionText: nil))
            if splitLinkHost.canOpenLink(context.tabID, context.assignment) {
                actions.append(
                    BrowserPageContextMenuAction(
                        kind: .split, title: String(localized: "Open Link in Split View"),
                        symbolName: "rectangle.split.2x1", linkURL: linkURL, selectionText: nil))
            }
        }
        if let selectionText,
            let search = linkDestinationHost.selectionSearch(for: selectionText, from: source)
        {
            actions.append(
                BrowserPageContextMenuAction(
                    kind: .search, title: String(localized: "Search with \(search.engineTitle)"),
                    symbolName: "magnifyingglass", linkURL: nil, selectionText: selectionText))
        }
        return actions
    }

    /// Runs a row the menu offered, while the page still offers it for the
    /// same link or selection.
    @discardableResult
    func performContextMenuAction(_ action: BrowserPageContextMenuAction) -> Bool {
        guard
            contextMenuActions(linkURL: action.linkURL, selectionText: action.selectionText)
                .contains(where: { $0.kind == action.kind }),
            let context = navigationContext
        else { return false }
        let source = BrowserTabRuntimeAssignment(
            tabID: context.tabID, spaceID: context.spaceID,
            profileID: context.assignment.profileID)
        switch action.kind {
        case .search:
            guard let selectionText = action.selectionText,
                let search = linkDestinationHost.selectionSearch(for: selectionText, from: source)
            else { return false }
            return linkDestinationHost.openLink(
                search.url, from: source, in: context.assignment)
        case .peek:
            guard let linkURL = action.linkURL else { return false }
            openPeek(
                BrowserPeekRequest(
                    url: linkURL, sourceTabID: context.tabID, sourceTitle: context.title,
                    spaceAssignment: context.assignment, trigger: .contextMenu))
            return true
        case .split:
            guard let linkURL = action.linkURL else { return false }
            openLinkInSplitView(linkURL)
            return true
        case .space(let id):
            guard let linkURL = action.linkURL,
                let space = linkDestinationHost.otherSpaces(from: source).first(where: { $0.id == id })
            else { return false }
            return linkDestinationHost.openLink(
                linkURL, from: source, in: BrowserSpaceRuntimeAssignment(space: space))
        }
    }
}
