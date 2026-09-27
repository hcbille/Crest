import Foundation

/// Each session change updates the workspace it names and the images its tabs
/// wear. The images move first, while the read model still holds what the
/// change replaces, so a tab a change places anew is told apart from one it
/// keeps. Each change also marks its workspace touched, so the windows over
/// that session follow it once the batch is applied.
extension CoreState {
    // MARK: - Actions - Images

    /// The images the platform kept for the tabs of a workspace that opened
    /// before they were offered, as the persistent session a launch loads
    /// does: each tab the workspace holds that wears none takes its own.
    func adoptImages(_ images: [UUID: Data], in workspaceID: UUID) {
        guard let workspace = workspaces[workspaceID] else { return }
        let held = Set(workspace.tabIDs)
        favicons.adopt(images) { held.contains($0) }
    }

    // MARK: - Actions - Batches

    /// A batch of changes was applied: images of tabs a change removed and no
    /// workspace holds any longer are gone.
    func finishBatch() {
        favicons.finishBatch { tabID in workspaces.values.contains { $0.holds(tabID: tabID) } }
    }

    // MARK: - Actions - Changes

    func apply(_ change: WorkspaceOpened) {
        if let workspace = workspaces[change.workspaceID] {
            favicons.detach(workspace.tabIDs)
            favicons.place(change.session.spaces.flatMap(Self.tabIDs), in: change.workspaceID)
            workspace.apply(change)
        } else {
            favicons.place(change.session.spaces.flatMap(Self.tabIDs), in: change.workspaceID)
            publish(WorkspaceModel(change), forKey: change.workspaceID, into: \.workspacesStorage, as: \.workspaces)
        }
        touch(change.workspaceID)
    }

    func apply(_ change: WorkspaceClosed) {
        if let workspace = workspacesStorage[change.workspaceID] {
            favicons.detach(workspace.tabIDs)
            publish(nil, forKey: change.workspaceID, into: \.workspacesStorage, as: \.workspaces)
        }
        touch(change.workspaceID)
    }

    func apply(_ change: WorkspaceChanged) {
        workspaces[change.workspaceID]?.apply(change)
        touch(change.workspaceID)
    }

    func apply(_ change: AppPreferencesChanged) {
        workspaces[change.workspaceID]?.apply(change)
        touch(change.workspaceID)
    }

    func apply(_ change: SpacesChanged) {
        if let workspace = workspaces[change.workspaceID] {
            for spaceID in change.removed { favicons.detach(workspace.spaces.model(spaceID)?.tabIDs ?? []) }
            favicons.place(change.added.flatMap(Self.tabIDs), in: change.workspaceID)
            workspace.apply(change)
        }
        touch(change.workspaceID)
    }

    func apply(_ change: SpaceSettingsChanged) {
        space(change.spaceID, in: change.workspaceID)?.apply(change)
        touch(change.workspaceID)
    }

    func apply(_ change: TabsChanged) {
        if let space = space(change.spaceID, in: change.workspaceID) {
            let gone = Set(change.removed)
            favicons.detach(change.removed)
            favicons.place(
                change.updated.map(\.id).filter { !space.tabs.contains($0) || gone.contains($0) },
                in: change.workspaceID)
            space.apply(change)
        }
        touch(change.workspaceID)
    }

    func apply(_ change: FoldersChanged) {
        space(change.spaceID, in: change.workspaceID)?.apply(change)
        touch(change.workspaceID)
    }

    func apply(_ change: SplitGroupsChanged) {
        space(change.spaceID, in: change.workspaceID)?.apply(change)
        touch(change.workspaceID)
    }

    /// The sidebar's lists are the read model's alone: windows need not
    /// follow them.
    func apply(_ change: SidebarChanged) {
        space(change.spaceID, in: change.workspaceID)?.apply(change)
    }

    func apply(_ change: HistoryChanged) {
        space(change.spaceID, in: change.workspaceID)?.apply(change)
        touch(change.workspaceID)
    }

    func apply(_ change: ArchiveChanged) {
        if let space = space(change.spaceID, in: change.workspaceID) {
            let gone = Set(change.removed)
            favicons.detach(change.removed)
            favicons.place(
                change.archived.map(\.tab.id).filter { !space.archive.contains(tabID: $0) || gone.contains($0) },
                in: change.workspaceID)
            space.apply(change)
        }
        touch(change.workspaceID)
    }

    func apply(_ change: TabCopied) {
        if workspaces[change.workspaceID]?.holdsOpen(tabID: change.copyTabID) == true {
            favicons.copy(change.sourceTabID, to: change.copyTabID, in: change.workspaceID)
        }
        touch(change.workspaceID)
    }

    func apply(_ change: TabsImported) {
        if let workspace = workspaces[change.workspaceID] {
            favicons.place(imported: change.tabs.filter { workspace.holds(tabID: $0.tabID) }, in: change.workspaceID)
        }
        touch(change.workspaceID)
    }

    /// A promoted page changes no state of its own: the session's changes
    /// before it carry the new tab, and the window that promoted it reads it
    /// from the changes its intent answered.
    func apply(_ change: TransientPagePromoted) {}

    func apply(_ change: TabFaviconAssigned) {
        if workspaces[change.workspaceID]?.holdsOpen(tabID: change.tabID) == true {
            favicons.assign(adopts: change.adopts, to: change.tabID, in: change.workspaceID, from: change.pageID)
        }
        touch(change.workspaceID)
    }

    private func space(_ spaceID: UUID, in workspaceID: UUID) -> SpaceModel? {
        workspaces[workspaceID]?.spaces.model(spaceID)
    }

    /// Every tab a Space holds, open or archived.
    private static func tabIDs(of space: SpaceState) -> [UUID] {
        space.tabs.map(\.id) + space.archivedTabs.map(\.tab.id)
    }

    private func touch(_ workspace: UUID) {
        touchedWorkspaces.insert(workspace)
    }
}
