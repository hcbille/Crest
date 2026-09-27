import Foundation

extension TabPagePutAway {
    /// A page put away changes no state of its own: the page host of the
    /// window that asked follows it, and lets the page go.
    @MainActor func apply(to state: CoreState) {}
}
