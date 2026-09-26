namespace CrestCore.Contracts;

/// A link in the page asked to open in Peek, as the core decided (`Decision`),
/// and the engine kept the page where it was. `StagedLinkId` names the link the
/// engine staged for the Peek's first load, which keeps its referrer and
/// initiator; without one the Peek loads `Url` afresh. A Peek that does not
/// open discards the staged link.
public sealed record PeekRequested(Guid PageId, string Url, LinkNavigationDecision Decision, Guid? StagedLinkId)
    : EnginePresentation;
