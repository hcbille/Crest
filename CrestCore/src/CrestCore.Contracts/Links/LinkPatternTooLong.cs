namespace CrestCore.Contracts;

/// A route's pattern is longer than `Maximum` characters.
public sealed record LinkPatternTooLong(int Maximum) : Rejection;
