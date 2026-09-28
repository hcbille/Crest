import SwiftUI

/// The badge a tab's icon wears while its page runs on an engine the core
/// badges: on a device with more than one engine, every engine but the one new
/// pages open on. It follows the page live, so moving the page to another
/// engine redraws only this badge, and a tab without a page wears none.
///
/// It reads the core from the environment and draws nothing where no window
/// supplies one, such as a drag preview.
struct TabEngineBadge: View {
    // MARK: - Variables

    let tabID: UUID

    /// The favicon's scale against a default-density row's.
    var scale: CGFloat = 1

    @Environment(CrestCore.self) private var core: CrestCore?

    var body: some View {
        if let engine = core?.state.engineBadge(forTab: tabID) {
            TabFaviconBadge(
                artwork: Image(systemName: engine.symbol), title: Text(engine.pageDescription), scale: scale)
        }
    }
}
