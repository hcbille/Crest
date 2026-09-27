import Foundation

extension WorkspaceChanged {
    @MainActor func apply(to state: CoreState) {
        state.workspaces[workspaceID]?.apply(self)
        state.touch(workspaceID)
    }
}
