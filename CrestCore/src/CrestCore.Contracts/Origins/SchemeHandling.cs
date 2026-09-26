namespace CrestCore.Contracts;

/// Which engine, if any, owns a navigation once its scheme is known. Only a
/// load Crest itself started may keep `file:`.
public sealed record SchemeHandling(string? Scheme, bool AppInitiated) : Query<SchemeHandled>;
