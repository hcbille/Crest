import Foundation

extension CoreState {
    func handle(_ change: PageOpened) {
        publish(PageStateModel(change.page), forKey: change.page.id, into: \.pagesStorage, as: \.pages)
    }

    /// A page that stays open keeps its object, which notifies only for what
    /// really changed.
    func handle(_ change: PageChanged) {
        if let page = pages[change.page.id] {
            page.update(change.page)
        } else {
            publish(PageStateModel(change.page), forKey: change.page.id, into: \.pagesStorage, as: \.pages)
        }
    }

    func handle(_ change: PageRemoved) {
        publish(nil, forKey: change.pageID, into: \.pagesStorage, as: \.pages)
    }

    /// An unloaded page is removed by the `PageRemoved` before it; its owner
    /// hears of it through `CrestCore.followUnloadedPages`.
    func handle(_ change: PageUnloaded) {}

    /// An adopted page arrives through the `PageOpened` before it; the window
    /// that hosts it hears of it through `CrestCore.followAdoptedPages`.
    func handle(_ change: OfferedPageAdopted) {}

    /// A recorded navigation changes no page: the session changes before it
    /// carry what it recorded, and `CrestCore` tells the engines' observers.
    func handle(_ change: NavigationRecorded) {}

    /// The `PageChanged` before it carries the page on its new engine; its
    /// followers hear of the move through `CrestCore.followRehostedPages`.
    func handle(_ change: PageRehosted) {}
}
