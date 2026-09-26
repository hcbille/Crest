namespace CrestCore.Contracts;

/// Stepping the tab `Offset` members along its split would move nothing.
public sealed record NoSplitStep(Guid TabId, int Offset) : Rejection;
