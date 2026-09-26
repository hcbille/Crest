namespace CrestCore.Contracts;

/// Reopens the tab the Space archived last, as `RestoreArchivedTab` reopens
/// one, and the window that asked shows it. Refused with `NoArchivedTabs` when
/// the Space keeps none.
public sealed record ReopenClosedTab(Guid WorkspaceId, Guid WindowId, Guid SpaceId) : SessionIntent(WorkspaceId);
