namespace CrestCore.Contracts;

/// The script dialogs a page can open.
public enum JavaScriptDialogKind {
    Alert,
    Confirm,
    Prompt,

    /// Whether to leave a page that asked to be kept.
    BeforeUnload
}
