import Foundation

/// Tells the person, in the window they are looking at, when the core moved
/// a page to another engine to play protected video, with an action that
/// moves it back: the page's site then opens on the engine it left.
@MainActor
final class BrowserEngineMoveNotices {
    // MARK: - Variables

    private weak var core: CrestCore?

    // MARK: - Initializers

    init(core: CrestCore) {
        self.core = core
        core.followRehostedPages(self) { [weak self] in self?.rehosted($0) }
    }

    // MARK: - Actions - Moves

    private func rehosted(_ move: PageRehosted) {
        guard move.reason == .protectedMedia, let origin = move.origin else { return }
        let engine = String(localized: move.to.title)
        BrowserNoticeCenter.shared.post(
            BrowserNotice(
                message: String(localized: "Moved to \(engine) to play protected video"),
                systemImage: "play.rectangle",
                action: BrowserNoticeAction(title: String(localized: "Move Back")) { [weak self] in
                    self?.core?.open(origin, in: move.spaceID, on: move.from, moving: move.pageID)
                }))
    }
}
