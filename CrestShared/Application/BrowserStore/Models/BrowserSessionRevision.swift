import Foundation

/// Where a window stands in what it shows: the revision the read model gives
/// its workspace's session, or nil once the core closed the workspace, and
/// how many times the window itself showed something else. It moves whenever
/// either does, so a reader that follows the window as a whole, such as its
/// page host, hears each change once.
struct BrowserSessionRevision: Equatable, Sendable {
    // MARK: - Variables

    let session: UInt64?
    let window: Int
}
