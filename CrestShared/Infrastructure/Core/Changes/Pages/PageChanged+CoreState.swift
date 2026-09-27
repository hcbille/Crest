import Foundation

extension PageChanged {
    /// A page that stays open keeps its object, which notifies only for what
    /// really changed.
    @MainActor func apply(to state: CoreState) {
        if let page = state.pages[self.page.id] {
            page.update(self.page)
        } else {
            state.publish(PageStateModel(self.page), forKey: self.page.id, into: \.pagesStorage, as: \.pages)
        }
    }
}
