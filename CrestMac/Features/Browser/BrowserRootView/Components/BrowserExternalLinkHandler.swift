import SwiftUI

struct BrowserExternalLinkHandler: ViewModifier {
    let browser: BrowserStore
    let pages: BrowserPagePool
    let chrome: BrowserChromeState
    let spaceAccess: BrowserSpaceAccessController
    let targetWindowID: UUID

    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .handlesExternalEvents(
                preferring:
                    BrowserExternalLinkScenePolicy.existingBrowserPreference,
                allowing:
                    BrowserExternalLinkScenePolicy.existingBrowserPreference
            )
            .onOpenURL { url in
                Task { await open(url) }
            }
    }

    private func open(_ url: URL) async {
        // A document opened from Finder, Open With, or `open -a Crest` has no host
        // for the link-preference rules to route on, and it is not a web link. It
        // belongs in the Space already on screen.
        if url.isFileURL {
            guard BrowserCorePolicy.acceptsLocalDocument(url),
                let spaceID = browser.shownSpace?.id,
                let assignment = await accessibleAssignment(for: spaceID)
            else { return }
            actions.openLocalDocuments([url], in: assignment)
            return
        }
        // The core routes the link and never to a locked Space: one a rule
        // names opens in a Quick Window on an unlocked Space instead, so a
        // link from another process never raises a prompt.
        guard BrowserCorePolicy.acceptsExternalURL(url),
            let placement = try? browser.core.query(
                RouteExternalLink(windowID: browser.windowID, url: url.absoluteString)),
            let spaceID = placement.spaceID,
            let assignment = await accessibleAssignment(for: spaceID)
        else { return }
        if placement.opensQuickWindow {
            openWindow(
                id: BrowserSceneID.quickWindow.rawValue,
                value: BrowserQuickWindowRequest(
                    url: url,
                    spaceAssignment: assignment,
                    targetWindowID: targetWindowID
                )
            )
            return
        }
        guard browser.openNewTab(url: url, matching: assignment) != nil else { return }
        pages.select()
        pages.navigate(to: url.absoluteString)
        chrome.dismissCommandPalette()
    }

    /// One implementation of local-document opening, shared with the File menu's
    /// Open File… rather than copied here.
    private var actions: BrowserCommandActions {
        BrowserCommandActions(
            browser: browser,
            pages: pages,
            chrome: chrome,
            openWindow: openWindow,
            spaceAccess: spaceAccess,
            targetWindowID: targetWindowID
        )
    }

    private func accessibleAssignment(
        for spaceID: UUID
    ) async -> BrowserSpaceRuntimeAssignment? {
        guard !browser.isDeleting(spaceID), let space = browser.spaceModel(spaceID) else { return nil }
        let assignment = BrowserSpaceRuntimeAssignment(space: space)
        guard await spaceAccess.unlock(space), browser.spaceModel(spaceID)?.profileID == assignment.profileID else {
            return nil
        }
        return assignment
    }
}
