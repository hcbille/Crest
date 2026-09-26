namespace CrestCore.Contracts;

/// A count of remembered identities below zero.
public sealed record InvalidMediaSessionCount(int Count) : Rejection;
