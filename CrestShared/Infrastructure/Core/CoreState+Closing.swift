import Foundation

extension CoreState {
    /// A close preparation's end and its question about downloads in progress
    /// change no model: `CrestCore.prepareToClose` hears the end, and the
    /// question's presenter follows prompts.
    func handle(_ change: CloseReady) {}

    func handle(_ change: QuitWithDownloadsAsked) {}
}
