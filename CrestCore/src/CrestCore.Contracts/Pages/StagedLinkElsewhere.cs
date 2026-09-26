namespace CrestCore.Contracts;

/// The page cannot load the link staged in `SourcePageId`: it lives on another
/// engine or profile, or its engine already holds its page.
public sealed record StagedLinkElsewhere(Guid PageId, Guid SourcePageId) : Rejection;
