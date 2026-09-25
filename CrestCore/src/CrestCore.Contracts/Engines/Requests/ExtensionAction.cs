namespace CrestCore.Contracts;

/// One extension's action: its name, badge text and icon as a PNG, whether it
/// is pinned, and whether it can run with no page to act on.
public sealed record ExtensionAction(string Id, string Name, string Badge, byte[]? Icon, bool Pinned, bool Enabled);
