import Foundation

extension CoreState {
    /// A close preparation's end and its question about downloads in progress
    /// change no model. TRANSITIONAL: the platform still runs the Chromium
    /// shell's close and quit preflight until that wiring moves to the core.
    func apply(_ change: CloseReady) {}

    func apply(_ change: QuitWithDownloadsAsked) {}
}
