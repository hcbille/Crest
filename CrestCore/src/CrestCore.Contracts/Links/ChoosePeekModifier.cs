namespace CrestCore.Contracts;

/// Chooses the key that opens a clicked link in Peek.
public sealed record ChoosePeekModifier(LinkPeekModifier Modifier) : LinkIntent;
