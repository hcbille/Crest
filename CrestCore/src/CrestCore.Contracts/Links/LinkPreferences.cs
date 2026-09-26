namespace CrestCore.Contracts;

/// How links behave on this device: where a link from another app opens, what
/// a clicked link does, how long a Quick Window lives, and the routes that send
/// matching links to a Space. The device store keeps them and never syncs
/// them.
public sealed record LinkPreferences(ExternalLinkDestination Destination, Guid? DestinationSpaceId, bool FocusesNewTabs,
    bool FollowsMovedTabs, bool OpensPeekAutomatically, LinkPeekModifier PeekModifier, bool DragsLinksToPeek,
    QuickWindowArchivePolicy ArchivePolicy, bool RemembersSpaceBySite, IReadOnlyList<LinkRoute> Routes,
    IReadOnlyList<RememberedSite> RememberedSites) {
    #region Actions - Equality

    public bool Equals(LinkPreferences? other) => other is not null
        && Destination == other.Destination && DestinationSpaceId == other.DestinationSpaceId
        && FocusesNewTabs == other.FocusesNewTabs && FollowsMovedTabs == other.FollowsMovedTabs
        && OpensPeekAutomatically == other.OpensPeekAutomatically && PeekModifier == other.PeekModifier
        && DragsLinksToPeek == other.DragsLinksToPeek && ArchivePolicy == other.ArchivePolicy
        && RemembersSpaceBySite == other.RemembersSpaceBySite && Routes.SequenceEqual(other.Routes)
        && RememberedSites.SequenceEqual(other.RememberedSites);

    public override int GetHashCode() => HashCode.Combine(Destination, DestinationSpaceId, Routes.Count, RememberedSites.Count);

    #endregion
}
