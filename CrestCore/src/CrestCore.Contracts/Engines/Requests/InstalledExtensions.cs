namespace CrestCore.Contracts;

/// The extensions installed in the profile `ProfileId` names, for Settings.
public sealed record InstalledExtensions(Guid ProfileId) : PageRequest<InstalledExtensionList>;
