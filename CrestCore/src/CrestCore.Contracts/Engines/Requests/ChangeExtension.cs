namespace CrestCore.Contracts;

/// Changes an installed extension in the profile `ProfileId` names. False when
/// the person may not change it.
public sealed record ChangeExtension(Guid ProfileId, string ExtensionId, ExtensionChange Change) : PageRequest<bool>;
