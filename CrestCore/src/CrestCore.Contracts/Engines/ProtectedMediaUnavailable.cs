namespace CrestCore.Contracts;

/// The page's document, or a frame of its own site, asked for `KeySystem`,
/// which the engine does not have. The core moves the page to an engine that
/// plays protected media through the platform, when one is registered.
public sealed record ProtectedMediaUnavailable(Guid PageId, KeySystem KeySystem) : EngineEvent;
