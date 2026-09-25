namespace CrestCore.Contracts;

/// The extension actions pinned in the profile `ProfileId` names, which its
/// Space shows whether or not a page is open. A private profile offers only
/// the extensions allowed in private windows.
public sealed record PinnedExtensions(Guid ProfileId) : PageRequest<ExtensionActionList>;
