import Foundation

extension SpaceSettingsChanged {
    @MainActor func apply(to state: CoreState) {
        state.space(spaceID, in: workspaceID)?.apply(self)
        state.touch(workspaceID)
    }
}
