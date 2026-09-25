namespace CrestCore.Contracts;

/// A Crest content script in `Frame` posted `Body`, as JSON, to `Handler`.
public sealed record ContentMessagePosted(Guid PageId, string Handler, string Body, ContentFrame Frame)
    : EnginePresentation;
