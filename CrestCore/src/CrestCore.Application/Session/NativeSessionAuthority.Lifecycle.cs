using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

public sealed partial class NativeSessionAuthority {
    #region Actions - Opening

    /// Opens the tab, which the issuing window shows when the intent asks.
    private SessionEdit OpeningTab(SessionState basis, OpenTab intent, DateTimeOffset now) {
        var space = Editable(basis, intent.SpaceId);
        if (basis.Spaces.Any(candidate => candidate.Tabs.Any(tab => tab.Id == intent.TabId)))
            throw new Rejected(new TabAlreadyExists(intent.TabId));
        var edited = BrowserTabCollection.Restore(space);
        var tab = BrowserTab.Restore(NewTab(intent.TabId, intent.Content, intent.Placement, now));
        edited.InsertTab(tab, intent.AfterTabId is { } origin ? edited.InsertionIndexAfter(origin) : null);
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        if (intent.Shows) followUp.ShowTab(space.Id, tab.Id).ShowSpace(space.Id);
        return new(Replacing(basis, edited.Capture(space)), SyncStaging.Creation, followUp);
    }

    /// Shows the Space's first open Start Page, outside splits when asked, or
    /// opens one after the tab the window shows there. Showing the one it has
    /// records its use, as showing a tab does.
    private SessionEdit ShowingStartPage(SessionState basis, ShowStartPage intent, DateTimeOffset now) {
        var space = Editable(basis, intent.SpaceId);
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        var edited = BrowserTabCollection.Restore(space);
        var draft = space.Tabs.FirstOrDefault(tab => tab.IsStartPage && !tab.Placement.IsDurable
            && (!intent.OutsideSplits || edited.SplitMembers(tab.Id).Count < 2));
        if (draft is null)
            return OpeningTab(basis, new OpenTab(intent.WorkspaceId, intent.WindowId, space.Id, intent.TabId,
                new TabContent(Address: null, View: null, Title: null, Symbol: null), TabPlacement.Current,
                AfterTabId: followUp.Window?.Tab(space.Id), Shows: true), now);
        followUp.ShowTab(space.Id, draft.Id).ShowSpace(space.Id);
        var used = StoredSessionCodec.Date(StoredSessionCodec.Seconds(now));
        return new(Replacing(basis, space with { Tabs = [.. space.Tabs.Select(tab => tab.Id == draft.Id ? tab with { LastActivatedAt = used } : tab)] }),
            SyncStaging.TabUse, followUp);
    }

    /// Opens an address for the window that asked: a Start Page it shows in
    /// the Space takes the address, and otherwise a new tab opens it after the
    /// tab it shows. The window shows the tab either way.
    private SessionEdit OpeningAddress(SessionState basis, OpenAddress intent, DateTimeOffset now, bool allowsInternalPages) {
        var space = Editable(basis, intent.SpaceId);
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        var shown = followUp.Window?.Tab(space.Id) is { } shownId ? space.Tabs.FirstOrDefault(tab => tab.Id == shownId) : null;
        if (shown is not { IsStartPage: true })
            return OpeningTab(basis, new OpenTab(intent.WorkspaceId, intent.WindowId, space.Id, intent.TabId,
                new TabContent(intent.Address, View: null, Title: null, Symbol: null), TabPlacement.Current, AfterTabId: shown?.Id,
                Shows: true), now);
        var navigated = NavigatingTab(basis, new NavigateTab(intent.WorkspaceId, space.Id, shown.Id, intent.Address), allowsInternalPages);
        followUp.ShowTab(space.Id, shown.Id).ShowSpace(space.Id);
        return navigated with { FollowUp = followUp };
    }

    /// A new tab in `placement`'s section showing `content`: a page titled by
    /// its title or host, a native view with the title and symbol it was
    /// given, or the Start Page. A saved or pinned page belongs to its address.
    private static TabState NewTab(Guid id, TabContent content, TabPlacement placement, DateTimeOffset now) {
        if (content.Address is not null && content.View is not null)
            throw new ArgumentException("A tab shows a page or a native view, not both.", nameof(content));
        var kind = content.View is { } view ? TabKind.Native(view.Kind, content.Title ?? "")
            : content.Address is null ? TabKind.StartPage : TabKind.Web;
        var address = content.Address is { } requested ? PageAddress(requested) : null;
        var title = address is not null ? PageTitle(address, content.Title)
            : content.View is not null ? content.Title ?? kind.Name : kind.Name;
        var symbol = content.View is not null ? content.Symbol ?? kind.Symbol : kind.Symbol;
        return new TabState(id, title, address?.OriginalString, content.View, placement.IsDurable ? address?.OriginalString : null,
            symbol, FaviconUrl: null, IconAccent: null, StoredIconMode: null, placement, FolderId: null, SplitGroupId: null, now,
            PositionModifiedAt: null, CustomTitle: null, TitleModifiedAt: null, KeepsPageLoaded: false);
    }

    /// `address` as a page loads it. Refused with `UnsupportedAddress` for one
    /// that is not absolute.
    private static Uri PageAddress(string address) =>
        Uri.TryCreate(address, UriKind.Absolute, out var parsed) ? parsed : throw new Rejected(new UnsupportedAddress(address));

    /// What a page is called until it reports its own title: `title`, or its
    /// host, or its whole address when it has no host.
    private static string PageTitle(Uri address, string? title) =>
        !string.IsNullOrEmpty(title) ? title : address.Host.Length > 0 ? address.Host : address.OriginalString;

    #endregion

    #region Actions - Closing

    /// Closes the tab the way its section closes one: a saved or pinned tab
    /// puts its page away, and an open tab is archived. A window that showed
    /// the tab returns to the one it showed before; one that put a saved or
    /// pinned tab away skips its split, whose other members would present it
    /// again.
    private SessionEdit ClosingTab(SessionState basis, CloseTab intent, DateTimeOffset now) {
        var space = Editable(basis, intent.SpaceId);
        var edited = BrowserTabCollection.Restore(space);
        var tab = edited.Tab(intent.TabId);
        var action = TabDismissalAction.Of(tab.Placement, tab.Content.IsStartPage, space.Tabs.Count);
        if (action.ClosesWindow) throw new Rejected(new LastStartPage(tab.Id));
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        var shown = followUp.Window?.Tab(space.Id);
        Guid? selected;
        if (action.KeepsTab) {
            var group = tab.SplitGroupId;
            var fallback = followUp.FallbackAfterDismissing(space.Id, tab.Id, space.Tabs
                .Where(candidate => candidate.Id != tab.Id && (group is null || candidate.SplitGroupId != group))
                .Select(candidate => candidate.Id).ToHashSet());
            selected = edited.CloseDurable(tab.Id, shown, fallback, ClosePolicy(basis) == SavedTabClosePolicy.ReturnToSavedUrl);
        } else {
            var fallback = followUp.FallbackAfterDismissing(space.Id, tab.Id, space.Tabs.Select(candidate => candidate.Id).ToHashSet());
            selected = edited.DismissTabs([tab.Id], shown, fallback, now, deleting: false, ensureSelection: false,
                resetArchivePlacement: false);
            edited.PruneSplitMetadata();
        }
        followUp.ShowTab(space.Id, selected);
        return new(Replacing(basis, edited.Capture(space)), SyncStaging.Creation, followUp);
    }

    /// Deletes the tab into the archive as an open tab. The issuing window
    /// shows the tab it showed before, or the one its Space falls back to.
    private SessionEdit DeletingTab(SessionState basis, DeleteTab intent, DateTimeOffset now) {
        var space = Editable(basis, intent.SpaceId);
        var edited = BrowserTabCollection.Restore(space);
        _ = edited.Tab(intent.TabId);
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        var fallback = followUp.FallbackAfterDismissing(space.Id, intent.TabId, space.Tabs.Select(tab => tab.Id).ToHashSet());
        var selected = edited.DismissTabs([intent.TabId], followUp.Window?.Tab(space.Id), fallback, now, deleting: true,
            ensureSelection: true, resetArchivePlacement: true);
        edited.PruneSplitMetadata();
        followUp.ShowTab(space.Id, selected);
        return new(Replacing(basis, edited.Capture(space)), SyncStaging.Deletion, followUp);
    }

    /// Archives the Space's open tabs. The issuing window shows the tab it
    /// showed there when that tab stays, or the one the Space falls back to.
    private SessionEdit ClearingCurrentTabs(SessionState basis, ClearCurrentTabs intent, DateTimeOffset now) {
        var space = Editable(basis, intent.SpaceId);
        var edited = BrowserTabCollection.Restore(space);
        var open = edited.Tabs.Where(tab => !tab.Placement.IsDurable).Select(tab => tab.Id).ToArray();
        if (open.Length == 0) throw new Rejected(new NoCurrentTabs(space.Id));
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        var selected = edited.DismissTabs(open, followUp.Window?.Tab(space.Id), null, now, deleting: false, ensureSelection: true,
            resetArchivePlacement: false);
        edited.PruneSplitMetadata();
        followUp.ShowTab(space.Id, selected);
        return new(Replacing(basis, edited.Capture(space)), SyncStaging.Creation, followUp);
    }

    /// Where a saved or pinned tab's page returns when it is put away. The
    /// app's preferences live in the persistent session, which every other
    /// workspace follows.
    private SavedTabClosePolicy ClosePolicy(SessionState basis) =>
        (basis.AppPreferences ?? device?.PersistentPreferences() ?? AppPreferencesPolicy.Default).SavedTabClose;

    #endregion

    #region Actions - Copying and moving

    /// Copies the tab, starting from where its page is now; see
    /// `StartFromSourcePage`. The issuing window shows the copy when the
    /// intent asks.
    private SessionEdit DuplicatingTab(SessionState basis, DuplicateTab intent, DateTimeOffset now, IIdSource ids, Pages? pages) {
        var space = Editable(basis, intent.SpaceId);
        var edited = BrowserTabCollection.Restore(space);
        if (edited.Tab(intent.TabId).Content.IsStartPage) throw new Rejected(new StartPageNotCopied(intent.TabId));
        var copy = edited.DuplicateTab(intent.TabId, ids, now, intent.Placement ?? TabPlacement.Current);
        StartFromSourcePage(copy, intent.TabId, intent.WindowId, pages);
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        if (intent.Shows) followUp.ShowTab(space.Id, copy.Id).ShowSpace(space.Id);
        return new(Replacing(basis, edited.Capture(space)), SyncStaging.Creation, followUp,
            new([new SessionTabCopy(intent.TabId, copy.Id)], null));
    }

    /// Moves a pinned tab to the open tabs and any other tab to the pinned
    /// tabs, each at the end of its section.
    private SessionEdit TogglingPin(SessionState basis, TogglePin intent, DateTimeOffset now) {
        var pinned = Editable(basis, intent.SpaceId).Tabs.FirstOrDefault(tab => tab.Id == intent.TabId)?.Placement == TabPlacement.Pinned;
        return MovingTab(basis, new MoveTab(intent.WorkspaceId, intent.SpaceId, intent.TabId,
            pinned ? TabPlacement.Current : TabPlacement.Pinned, FolderId: null, BeforeTabId: null, LeavesSplit: false), now);
    }

    /// Moves the tab, which leaves its split for a section that holds none.
    /// One that leaves its split takes the split's metadata with it when no
    /// other tab keeps it.
    private SessionEdit MovingTab(SessionState basis, MoveTab intent, DateTimeOffset now) =>
        Organizing(basis, intent.SpaceId, SyncStaging.Edit, edited => {
            bool leaves = intent.LeavesSplit || !intent.Placement.HoldsSplits;
            edited.MoveTab(intent.TabId, intent.Placement, intent.FolderId, intent.BeforeTabId, leaves, now);
            if (leaves) edited.PruneSplitMetadata();
        });

    #endregion
}
