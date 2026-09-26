using CrestCore.Contracts;

namespace CrestCore.Application;

/// Which of the Spaces a browser brought each of its saved passwords belongs
/// with. A browser whose Spaces are its profiles gives a password to its
/// profile's Space, else to the first Space holding the password's site, else
/// to its first Space; one that names its own Spaces gives it to every Space
/// holding its site. A browser that keeps no passwords routes none.
internal static class ImportPasswordRouting {
    #region Actions - Routing

    /// How many of `passwords` belong with each of `spaces`, by Space.
    public static IReadOnlyDictionary<Guid, int> Counts(ImportSource source, IReadOnlyList<ImportPasswordSource> passwords,
        IReadOnlyList<SpaceState> spaces) {
        ArgumentNullException.ThrowIfNull(passwords);
        var hosts = Hosts(spaces);
        var counts = new Dictionary<Guid, int>();
        foreach (var password in passwords)
            foreach (var spaceId in SourceSpaces(source, password, spaces, hosts))
                counts[spaceId] = counts.GetValueOrDefault(spaceId) + 1;
        return counts;
    }

    /// Where each of `passwords` goes once `review` is imported into
    /// `session`: the destination of each reviewed Space that brings its
    /// passwords and that the password belongs with, leaving out a
    /// destination `session` no longer holds or `isLocked` holds shut.
    public static ImportPasswordRoutes Destinations(SetupImportReview review, IReadOnlyList<ImportPasswordSource> passwords,
        SessionState session, Func<SpaceState, bool> isLocked) {
        ArgumentNullException.ThrowIfNull(review);
        ArgumentNullException.ThrowIfNull(passwords);
        ArgumentNullException.ThrowIfNull(session);
        ArgumentNullException.ThrowIfNull(isLocked);
        var bringing = review.Spaces.Where(space => space.BringsPasswords).ToArray();
        var destinations = bringing.GroupBy(space => space.Source.Id)
            .ToDictionary(group => group.Key, group => group.First().DestinationId ?? group.Key);
        var open = session.Spaces.Where(space => !isLocked(space)).Select(space => space.Id).ToHashSet();
        var sources = bringing.Select(space => space.Source).ToArray();
        var hosts = Hosts(sources);
        return new([.. passwords.Select(password => new ImportPasswordRoute([.. SourceSpaces(review.Source, password, sources, hosts)
            .Select(spaceId => destinations[spaceId]).Distinct().Where(open.Contains)]))]);
    }

    /// The Spaces among `spaces` that `password` belongs with.
    private static IEnumerable<Guid> SourceSpaces(ImportSource source, ImportPasswordSource password, IReadOnlyList<SpaceState> spaces,
        IReadOnlyDictionary<Guid, HashSet<string>> hosts) {
        if (!source.SuppliesPasswords) return [];
        var holdingSite = spaces.Where(space => hosts[space.Id].Contains(password.Host)).ToArray();
        if (source.NamesItsSpaces) return holdingSite.Select(space => space.Id);
        var profile = spaces.FirstOrDefault(space => string.Equals(space.Settings.Name, password.ProfileName,
            StringComparison.InvariantCultureIgnoreCase));
        var chosen = profile ?? holdingSite.FirstOrDefault() ?? spaces.FirstOrDefault();
        return chosen is null ? [] : [chosen.Id];
    }

    /// The hosts each Space's tabs show or were saved at, compared ignoring case.
    private static IReadOnlyDictionary<Guid, HashSet<string>> Hosts(IReadOnlyList<SpaceState> spaces) {
        ArgumentNullException.ThrowIfNull(spaces);
        var hosts = new Dictionary<Guid, HashSet<string>>();
        foreach (var space in spaces)
            hosts[space.Id] = space.Tabs.Select(tab => ImportAddress.Read(tab.SavedUrl ?? tab.Url)?.Host).OfType<string>()
                .ToHashSet(StringComparer.InvariantCultureIgnoreCase);
        return hosts;
    }

    #endregion
}
