namespace CrestCore.Contracts;

/// The person's answer to the dialog `JavaScriptDialogRequested` presented.
/// TRANSITIONAL until page dialogs move to the core (WP C (e)).
public sealed record AnswerJavaScriptDialog(Guid PageId, Guid DialogId, bool Accepted, string? Input)
    : PageRequest<bool>;
