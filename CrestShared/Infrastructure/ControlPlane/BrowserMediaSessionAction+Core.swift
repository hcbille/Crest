import Foundation

extension BrowserMediaSessionAction {
    /// The control as the core's contracts name it.
    var core: MediaSessionAction {
        switch self {
        case .play: .play
        case .pause: .pause
        case .previousTrack: .previousTrack
        case .nextTrack: .nextTrack
        }
    }
}
