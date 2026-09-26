import Foundation

extension CoreState {
    /// A question waiting on the person changes no model: `CrestCore` hands it
    /// to the engine whose page shows it, and the person's answer goes back
    /// to the core as an intent.
    func apply(_ change: ScriptDialogAsked) {}

    func apply(_ change: AuthenticationAsked) {}

    func apply(_ change: PermissionAsked) {}

    func apply(_ change: ExtensionInstallAsked) {}

    func apply(_ change: DownloadDestinationAsked) {}

    func apply(_ change: DownloadApprovalAsked) {}

    func apply(_ change: PromptSettled) {}
}
