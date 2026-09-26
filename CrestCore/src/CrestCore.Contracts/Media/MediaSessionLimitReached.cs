namespace CrestCore.Contracts;

/// More sessions than the store orders at once.
public sealed record MediaSessionLimitReached(int Maximum) : Rejection;
