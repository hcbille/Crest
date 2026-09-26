namespace CrestCore.Contracts;

/// A document in the page opened a script dialog: an alert, a confirmation, a
/// prompt with `DefaultText`, or the question whether to leave the page. The
/// page waits for `AnswerJavaScriptDialog`. TRANSITIONAL until page dialogs
/// move to the core (WP C (e)).
public sealed record JavaScriptDialogRequested(Guid PageId, Guid DialogId, JavaScriptDialogKind Kind, string Message,
    string DefaultText, string SourceUrl) : EnginePresentation;
