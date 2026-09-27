import Foundation

/// One walk of a workspace in the read model supplies both runtime
/// reconciliation and archive retention. The platform still controls how pages
/// are released and presented.
@MainActor
struct BrowserPageReconciliation {
    // MARK: - Variables

    let validAssignments: Set<BrowserTabRuntimeAssignment>
    let invalidTabIDs: Set<TabID>
    let tabIDsToArchive: Set<TabID>
    let navigationContexts: [(page: BrowserPlatformPage, tab: BrowserPageTab)]
    let retainedTabIDsByProfileID: [UUID: Set<TabID>]

    // MARK: - Initializers

    /// Reconciles `residentPages` with `workspace`, whose tabs wear the icons
    /// `images` keeps. A workspace the core no longer holds keeps no page.
    init(
        workspace: WorkspaceModel?,
        images: FaviconAssets,
        residentPages: some Sequence<(TabID, BrowserPlatformPage)>
    ) {
        var tabsByID: [TabID: (tab: TabStateModel, assignment: BrowserTabRuntimeAssignment)] = [:]
        var archivedAssignments: [TabID: BrowserSpaceRuntimeAssignment] = [:]
        var keptTabIDsByProfileID: [UUID: Set<TabID>] = [:]
        for space in workspace?.spaces.models ?? [] {
            let spaceAssignment = BrowserSpaceRuntimeAssignment(space: space)
            for tab in space.tabs.models {
                let assignment = BrowserTabRuntimeAssignment(tabID: tab.id, spaceID: space.id, profileID: space.profileID)
                precondition(tabsByID[tab.id] == nil)
                tabsByID[tab.id] = (tab, assignment)
            }
            for archived in space.archive.entries {
                precondition(archivedAssignments[archived.tab.id] == nil)
                archivedAssignments[archived.tab.id] = spaceAssignment
            }
            keptTabIDsByProfileID[space.profileID, default: []].formUnion(space.tabIDs)
        }
        validAssignments = Set(tabsByID.values.map(\.assignment))
        retainedTabIDsByProfileID = keptTabIDsByProfileID

        var invalid: Set<TabID> = []
        var toArchive: Set<TabID> = []
        var contexts: [(page: BrowserPlatformPage, tab: BrowserPageTab)] = []
        for (tabID, page) in residentPages {
            if let entry = tabsByID[tabID], entry.tab.nativeContent == nil,
                entry.assignment.spaceID == page.spaceID,
                entry.assignment.profileID == page.profileID
            {
                contexts.append((page, BrowserPageTab(entry.tab, images: images)))
                continue
            }
            invalid.insert(tabID)
            if let assignment = archivedAssignments[tabID],
                assignment.spaceID == page.spaceID,
                assignment.profileID == page.profileID
            {
                toArchive.insert(tabID)
            }
        }
        invalidTabIDs = invalid
        tabIDsToArchive = toArchive
        navigationContexts = contexts
    }
}
