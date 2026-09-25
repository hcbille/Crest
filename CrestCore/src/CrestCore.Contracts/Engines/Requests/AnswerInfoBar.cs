namespace CrestCore.Contracts;

/// The person's answer to the bar `InfoBarShown` presented.
public sealed record AnswerInfoBar(Guid PageId, int InfoBarId, InfoBarAnswer Answer) : PageRequest<bool>;
