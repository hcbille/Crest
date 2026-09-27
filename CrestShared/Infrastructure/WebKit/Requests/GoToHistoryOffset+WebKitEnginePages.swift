import Foundation

extension GoToHistoryOffset {
    @MainActor func answer(on pages: WebKitEnginePages) -> Answer {
        pages.page(pageID).map { $0.engine.navigateHistory(by: offset) } != nil
    }
}
