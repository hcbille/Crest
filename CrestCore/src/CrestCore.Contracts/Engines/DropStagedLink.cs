namespace CrestCore.Contracts;

/// Forgets the link the engine staged as `StagedLinkId`, which no page will load.
public sealed record DropStagedLink(Guid StagedLinkId) : EngineCommand;
