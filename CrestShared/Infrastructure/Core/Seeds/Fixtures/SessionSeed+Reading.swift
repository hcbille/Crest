#if DEBUG
    import Foundation

    /// What a test reads back from a seed it built, in the words it reads a
    /// published Space in.
    extension SpaceState.Seed {
        // MARK: - Variables

        var pinnedTabs: [TabState.Seed] { tabs.filter { $0.placement == .pinned } }
        var savedTabs: [TabState.Seed] { tabs.filter { $0.placement == .saved } }
        var currentTabs: [TabState.Seed] { tabs.filter { !$0.placement.isDurable } }

        // MARK: - Actions - Reading

        /// Whether the seed holds the tab open.
        func contains(_ tabID: UUID) -> Bool {
            tabs.contains { $0.id == tabID }
        }
    }

    extension BrowserSpaceRuntimeAssignment {
        // MARK: - Initializers

        /// Where a seeded Space lives: its identity and profile.
        init(space: SpaceState.Seed) {
            self.init(spaceID: space.id, profileID: space.profileID)
        }
    }

    extension TabState.Seed {
        // MARK: - Variables

        /// The address the tab shows, as the platform reads addresses.
        var address: URL? { url.flatMap(URL.init(string:)) }
    }
#endif
