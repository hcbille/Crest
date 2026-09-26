namespace CrestCore.Contracts;

/// A document in a page opened a script dialog: an alert, a confirmation, a
/// prompt with `DefaultText`, or the question whether to leave the page.
/// `SourceUrl` is the address of the document that opened it.
public sealed record ScriptDialogQuestion(JavaScriptDialogKind Kind, string Message, string DefaultText, string SourceUrl);
