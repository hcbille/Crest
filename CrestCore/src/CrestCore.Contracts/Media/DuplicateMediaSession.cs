namespace CrestCore.Contracts;

/// Two sessions to order share one identity.
public sealed record DuplicateMediaSession(string Id) : Rejection;
