namespace CrestCore.Contracts;

/// What the person chose for one Space an import brings, and what those
/// choices mean: whether it comes in, the existing Space it joins or none for
/// a new Space, the name and look it takes, the tabs it brings and the
/// placements they move to, and its saved passwords. `DuplicateTabIds` are its
/// tabs the destination already holds, which it leaves out until the person
/// asks for them; `MatchedTabIds` are the destination's tabs it matches.
public sealed record SetupReviewSpace(SpaceState Source, bool Included, Guid? DestinationId, SpaceCustomization Customization,
    IReadOnlyList<Guid> IncludedTabIds, IReadOnlyList<Guid> DuplicateTabIds, IReadOnlyList<Guid> MatchedTabIds,
    IReadOnlyList<TabPlacementChoice> Placements, bool IncludesPasswords, int PasswordCount) {
    #region Variables

    /// The name the Space shows and takes once imported: the one chosen,
    /// trimmed, or "Untitled Space" for a blank one.
    [Resolved]
    public string ShownName => SpaceCustomization.Resolved(Customization.Name);

    /// Whether the passwords that belong with the Space come in with it.
    [Resolved]
    public bool BringsPasswords => Included && IncludesPasswords;

    #endregion
}
