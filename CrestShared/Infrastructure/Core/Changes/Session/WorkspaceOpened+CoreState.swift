import Foundation

extension WorkspaceOpened {
    @MainActor func apply(to state: CoreState) {
        if let workspace = state.workspaces[workspaceID] {
            state.favicons.detach(workspace.tabIDs)
            state.favicons.place(session.spaces.flatMap(CoreState.tabIDs), in: workspaceID)
            workspace.apply(self)
        } else {
            state.favicons.place(session.spaces.flatMap(CoreState.tabIDs), in: workspaceID)
            state.publish(WorkspaceModel(self), forKey: workspaceID, into: \.workspacesStorage, as: \.workspaces)
        }
        state.touch(workspaceID)
    }
}
