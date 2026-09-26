import Foundation

/// The session previews, isolated runs and tests open by default: a Work
/// Space and a Personal one, each with pinned, saved and current tabs and a
/// folder of saved ones.
enum SessionPreviewSeed {
    // MARK: - Actions - Building

    static func make() -> SessionState.Seed {
        SessionState.Seed(spaces: [makeWorkSpace(), makePersonalSpace()])
    }

    private static func makeWorkSpace() -> SpaceState.Seed {
        let folder = FolderState.Seed(title: "Build the Browser", symbol: "folder.fill")
        return SpaceState.Seed(
            name: "Work", symbol: "briefcase.fill", accent: .indigo, branding: SpaceAccent.rose.house,
            folders: [folder],
            tabs: workTabs(folderID: folder.id))
    }

    private static func workTabs(folderID: UUID) -> [TabState.Seed] {
        [
            tab("Apple", "https://apple.com", "apple.logo", .pinned),
            tab("GitHub", "https://github.com", "chevron.left.forwardslash.chevron.right", .pinned),
            tab("Linear", "https://linear.app", "line.3.horizontal.decrease.circle.fill", .pinned),
            tab("WebKit", "https://webkit.org", "safari.fill", .pinned),
            tab(
                "Apple sidebars", "https://developer.apple.com/design/human-interface-guidelines/sidebars",
                "sidebar.left", .saved, folderID),
            tab(
                "WebKit for SwiftUI", "https://developer.apple.com/videos/play/wwdc2025/231/", "play.rectangle.fill",
                .saved, folderID),
            tab("SwiftUI", "https://developer.apple.com/xcode/swiftui/", "swift", .saved, folderID),
            tab(
                "Liquid Glass notes", "https://developer.apple.com/documentation/technologyoverviews/liquid-glass",
                "drop.fill", .current),
            .startPage(),
        ]
    }

    private static func makePersonalSpace() -> SpaceState.Seed {
        let folder = FolderState.Seed(title: "Reading", symbol: "folder.fill")
        return SpaceState.Seed(
            name: "Personal", symbol: "house.fill", accent: .orange, branding: SpaceAccent.indigo.house,
            folders: [folder],
            tabs: [
                tab("Apple", "https://apple.com", "apple.logo", .pinned),
                tab("YouTube", "https://youtube.com", "play.fill", .pinned),
                tab("Music", "https://music.apple.com", "music.note", .pinned),
                tab("Maps", "https://maps.apple.com", "map.fill", .pinned),
                tab("WebKit blog", "https://webkit.org/blog/", "text.page.fill", .saved, folder.id),
                tab("Weekend ideas", "https://www.nps.gov", "leaf.fill", .current),
            ])
    }

    private static func tab(
        _ title: String, _ address: String, _ symbol: String, _ placement: TabPlacement, _ folderID: UUID? = nil
    ) -> TabState.Seed {
        TabState.Seed(title: title, url: URL(string: address), symbol: symbol, placement: placement, folderID: folderID)
    }
}

extension SessionState.Seed {
    // MARK: - Variables

    /// The session previews, isolated runs and tests open by default.
    static let preview = SessionPreviewSeed.make()

    // MARK: - Actions - Building

    /// The preview session with every open tab stale in the Space a window
    /// opens on, and one more stale tab there. Cleanup keeps the one that
    /// window shows.
    static func cleanupFixture(now: Date) -> SessionState.Seed {
        var session = preview
        let launchSpaceID = session.defaultSpaceID ?? session.spaces.first?.id
        guard let spaceIndex = session.spaces.firstIndex(where: { $0.id == launchSpaceID }) else { return session }
        let stale = now.addingTimeInterval(-13 * 60 * 60)
        for tabIndex in session.spaces[spaceIndex].tabs.indices
        where !session.spaces[spaceIndex].tabs[tabIndex].placement.isDurable {
            session.spaces[spaceIndex].tabs[tabIndex].lastActivatedAt = stale
        }
        session.spaces[spaceIndex].tabs.append(
            TabState.Seed(
                title: "Old research", url: URL(string: "https://example.com/old"), placement: .current,
                lastActivatedAt: stale))
        return session
    }
}

extension SpaceModel {
    // MARK: - Static Variables

    /// The preview session's Spaces as the core resolves them, held by no
    /// workspace: what a preview that draws Spaces without a window shows.
    static let previewSpaces = SpaceModel.detached(SessionState.Seed.preview)
}
