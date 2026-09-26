import Foundation

/// A request to prepare closing pages, windows or the app, which the core
/// answers with a `CloseReady` naming `requestID`.
protocol CloseRequest: CloseIntent {
    var requestID: UUID { get }
}

extension PrepareToClosePages: CloseRequest {}

extension PrepareToCloseWindows: CloseRequest {}

extension PrepareToQuit: CloseRequest {}
