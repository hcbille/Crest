#if DEBUG
    import Foundation

    extension BrowserStore {
        /// The session this window's workspace holds now, as the seed another
        /// window's workspace would open from, for tests that carry what one
        /// store did into the next or compare it with what it held before.
        var sessionSeed: SessionState.Seed {
            SessionState.Seed(
                spaces: spaceModels.map(\.value.seed), defaultSpaceID: workspaceModel?.defaultSpaceID,
                disposableSeedMarker: nil)
        }
    }
#endif
