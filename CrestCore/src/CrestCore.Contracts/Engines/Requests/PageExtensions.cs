namespace CrestCore.Contracts;

/// The extension actions the page's toolbar offers, with each one's state for
/// the page's own tab: its badge, its icon and whether it is pinned.
public sealed record PageExtensions(Guid PageId) : PageRequest<ExtensionActionList>;
