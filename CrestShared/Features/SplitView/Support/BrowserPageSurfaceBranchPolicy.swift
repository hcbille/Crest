import Foundation

/// The decision a content area makes before it draws anything: columns or the
/// single page surface, and for which Space.
///
/// Written once because both shells were writing it, and a disagreement is not
/// cosmetic — the two layouts host the live web view in different places, so a
/// shell that opens columns one condition earlier than the other rebuilds a
/// page's host where the other does not. Which tabs are cards is the core's:
/// the window's `cards(in:)`.
@MainActor
enum BrowserPageSurfaceBranchPolicy {
    // MARK: - Actions - Resolving

    /// - Parameters:
    ///   - cards: The tabs the window shows side by side in `space`.
    ///   - hasEnteredSplitContent: Whether a drag has already reached the
    ///     content area during this lift. It holds the columns layout open
    ///     around a single presented tab for the rest of the drag rather than
    ///     following the pointer back and forth, because every flip between the
    ///     two layouts hands the live web view to a different host, while the
    ///     placeholder coming and going inside the columns layout is only a
    ///     width change.
    ///   - resolvedTarget: Where the lift in flight would land. Only a
    ///     `.splitInsert` aimed at this very Space opens a slot in this row.
    static func resolve(
        space: SpaceModel?,
        isLocked: Bool,
        cards: [TabStateModel],
        hasEnteredSplitContent: Bool,
        resolvedTarget: BrowserSidebarReorderTarget?,
        presentsTrailingPanel: Bool = false
    ) -> BrowserPageSurfacePresentation {
        guard let space, !isLocked else { return .unavailable }
        guard !cards.isEmpty, cards.count > 1 || hasEnteredSplitContent || presentsTrailingPanel else {
            return .single(space: space, cardTabID: cards.first?.id)
        }
        return .columns(
            space: space, members: cards,
            placeholderIndex: placeholderIndex(resolvedTarget: resolvedTarget, spaceID: space.id))
    }

    /// The slot a drag in flight would drop a card into, for this Space.
    private static func placeholderIndex(resolvedTarget: BrowserSidebarReorderTarget?, spaceID: UUID) -> Int? {
        guard case .splitInsert(let assignment, let index) = resolvedTarget?.kind, assignment.spaceID == spaceID
        else { return nil }
        return index
    }
}
