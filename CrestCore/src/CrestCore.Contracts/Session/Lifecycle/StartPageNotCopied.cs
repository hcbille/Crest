namespace CrestCore.Contracts;

/// The tab shows the Start Page, which has nothing to copy.
public sealed record StartPageNotCopied(Guid TabId) : Rejection;
