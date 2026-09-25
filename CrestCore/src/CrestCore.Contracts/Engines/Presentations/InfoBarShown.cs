namespace CrestCore.Contracts;

/// The engine asks the person something in a bar over the page: a message and
/// the labels of the buttons it has. The person's answer is `AnswerInfoBar`.
public sealed record InfoBarShown(Guid PageId, int InfoBarId, string Message, string? AcceptLabel, string? CancelLabel,
    bool Closeable) : EnginePresentation;
