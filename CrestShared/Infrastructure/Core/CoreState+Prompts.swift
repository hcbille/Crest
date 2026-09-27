import Foundation

extension CoreState {
    /// A question waiting on the person changes no model: `CrestCore` hands it
    /// to the engine whose page shows it, and the person's answer goes back
    /// to the core as an intent.
    func handle(_ change: ScriptDialogAsked) {}

    func handle(_ change: AuthenticationAsked) {}

    func handle(_ change: PermissionAsked) {}

    func handle(_ change: ExtensionInstallAsked) {}

    func handle(_ change: DownloadDestinationAsked) {}

    func handle(_ change: DownloadApprovalAsked) {}

    func handle(_ change: PromptSettled) {}
}
