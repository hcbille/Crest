import Foundation

extension ScriptDialogAsked {
    /// A question waiting on the person changes no model: `CrestCore` hands it
    /// to the engine whose page shows it, and the person's answer goes back
    /// to the core as an intent.
    @MainActor func apply(to state: CoreState) {}
}
