namespace CrestCore.Contracts;

/// Opens `Address` for the window that asked, in a Space it shows: a Start Page
/// the window shows there takes the address, as `NavigateTab` gives one, and
/// otherwise a new tab, `TabId`, opens it after the tab the window shows. The
/// window shows the tab either way. Refused as `NavigateTab` and `OpenTab`
/// refuse.
public sealed record OpenAddress(Guid WorkspaceId, Guid WindowId, Guid SpaceId, Guid TabId, string Address)
    : SessionIntent(WorkspaceId);
