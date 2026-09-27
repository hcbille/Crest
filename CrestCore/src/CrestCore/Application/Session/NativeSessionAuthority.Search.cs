using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

public sealed partial class NativeSessionAuthority {
    #region Actions - Search engines

    /// `space` with its search choice edited by `edit`, through the rules a
    /// Space's engines follow. Stored engines that no longer validate are left
    /// out, as reading them does.
    internal SessionEdit Searching(SessionState basis, SpaceState space, Func<SearchPreferences, SearchPreferences> edit) =>
        SettingSpace(basis, space, settings => settings with {
            BrowsingPreferences = edit(SearchPreferences.Restore(settings.BrowsingPreferences)).Applied(settings.BrowsingPreferences)
        }, SyncStaging.Edit);

    /// A custom engine as the person typed it, trimmed and validated. Throws
    /// `Rejected` with `InvalidSearchEngine` naming its first flaw.
    internal SearchProvider Admitted(CustomSearchEngine engine) =>
        SearchProvider.Admit(engine.Id, engine.Name, engine.SearchTemplate, engine.SuggestionTemplate);

    #endregion

    #region Actions - Addresses

    /// What `input` loads with `provider`: no address when it names nothing a
    /// page can load.
    internal static ResolvedAddress Resolved(string input, SearchProvider provider, bool allowsInternalPages) {
        AddressResolution? resolution;
        try {
            resolution = AddressResolution.Resolve(input, provider, allowsInternalPages);
        } catch (BrowserRuleException) {
            return new(Url: null, SearchQuery: null);
        }
        return resolution is not null && Uri.TryCreate(resolution.Url, UriKind.Absolute, out _)
            ? new(resolution.Url, resolution.SearchQuery) : new(Url: null, SearchQuery: null);
    }

    /// The search choice of a Space of the accepted session. Throws `Rejected`
    /// with `UnknownSpace` for one it does not hold.
    internal SearchPreferences Searches(Guid spaceId) {
        SpaceState space;
        lock (Gate) space = session.Spaces.FirstOrDefault(candidate => candidate.Id == spaceId) ?? throw new Rejected(new UnknownSpace(spaceId));
        return SearchPreferences.Restore(space.Settings.BrowsingPreferences);
    }

    #endregion

    #region Actions - Browsing preferences

    /// Whether two states of one Space hold the same tabs, history and archive.
    internal bool SameRecords(SpaceState before, SpaceState after) =>
        before.Tabs.SequenceEqual(after.Tabs) && before.History.SequenceEqual(after.History)
        && before.ArchivedTabs.SequenceEqual(after.ArchivedTabs);

    #endregion
}
