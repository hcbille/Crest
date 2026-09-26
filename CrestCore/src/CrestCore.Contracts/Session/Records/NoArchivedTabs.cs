namespace CrestCore.Contracts;

/// The Space keeps no archived tab to reopen.
public sealed record NoArchivedTabs(Guid SpaceId) : Rejection;
