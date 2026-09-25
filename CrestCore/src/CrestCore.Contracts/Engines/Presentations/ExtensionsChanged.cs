namespace CrestCore.Contracts;

/// The extensions of the profile `ProfileId` names changed: one was added,
/// removed, enabled or pinned, or an action's state or icon changed.
public sealed record ExtensionsChanged(Guid ProfileId) : EnginePresentation;
