namespace CrestCore.Contracts;

/// The server as the prompt names it, or null when the challenge has no host
/// and the platform names Crest itself.
public sealed record AuthenticationSourceLabel(string? Label);
