import Foundation

extension CoreState {
    /// A close preparation's end and its question about downloads in progress
    /// change no model: `CrestCore.prepareToClose` hears the end, and the
    /// question's presenter follows prompts.
    func apply(_ change: CloseReady) {}

    func apply(_ change: QuitWithDownloadsAsked) {}
}
