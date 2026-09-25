namespace CrestCore.Contracts;

/// Extension actions, as an engine lists them.
public sealed record ExtensionActionList(IReadOnlyList<ExtensionAction> Actions);
