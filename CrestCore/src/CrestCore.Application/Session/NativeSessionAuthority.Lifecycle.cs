using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

internal sealed partial class NativeSessionAuthority {
    #region Actions - Opening

    /// Opens the tab, which the issuing window shows when the intent asks.
    public SessionEdit Handle(OpenTab intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        if (turn.Basis.Spaces.Any(candidate => candidate.Tabs.Any(tab => tab.Id == intent.TabId)))
            throw new Rejected(new TabAlreadyExists(intent.TabId));
        var edited = BrowserTabCollection.Restore(space);
        var tab = BrowserTab.Restore(NewTab(intent.TabId, intent.Content, intent.Placement, turn.Now));
        edited.InsertTab(tab, intent.AfterTabId is { } origin ? edited.InsertionIndexAfter(origin) : null);
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        if (intent.Shows) followUp.ShowTab(space.Id, tab.Id).ShowSpace(space.Id);
        return new(Replacing(turn.Basis, edited.Capture(space)), SyncStaging.Creation, followUp);
    }

    /// Shows the Space's first open Start Page, outside splits when asked, or
    /// opens one after the tab the window shows there. Showing the one it has
    /// records its use, as showing a tab does.
    public SessionEdit Handle(ShowStartPage intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        var edited = BrowserTabCollection.Restore(space);
        var draft = space.Tabs.FirstOrDefault(tab => tab.IsStartPage && !tab.Placement.IsDurable
            && (!intent.OutsideSplits || edited.SplitMembers(tab.Id).Count < 2));
        if (draft is null)
            return Handle(new OpenTab(intent.WorkspaceId, intent.WindowId, space.Id, intent.TabId,
                new TabContent(Address: null, View: null, Title: null), TabPlacement.Current,
                AfterTabId: followUp.Window?.Tab(space.Id), Shows: true), turn);
        followUp.ShowTab(space.Id, draft.Id).ShowSpace(space.Id);
        var used = StoredSessionCodec.Date(StoredSessionCodec.Seconds(turn.Now));
        return new(Replacing(turn.Basis, space with { Tabs = [.. space.Tabs.Select(tab => tab.Id == draft.Id ? tab with { LastActivatedAt = used } : tab)] }),
            SyncStaging.TabUse, followUp);
    }

    /// Opens an address for the window that asked: a Start Page it shows in
    /// the Space takes the address, and otherwise a new tab opens it after the
    /// tab it shows. The window shows the tab either way.
    public SessionEdit Handle(OpenAddress intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        var shown = followUp.Window?.Tab(space.Id) is { } shownId ? space.Tabs.FirstOrDefault(tab => tab.Id == shownId) : null;
        if (shown is not { IsStartPage: true })
            return Handle(new OpenTab(intent.WorkspaceId, intent.WindowId, space.Id, intent.TabId,
                new TabContent(intent.Address, View: null, Title: null), TabPlacement.Current, AfterTabId: shown?.Id,
                Shows: true), turn);
        var navigated = Handle(new NavigateTab(intent.WorkspaceId, space.Id, shown.Id, intent.Address), turn);
        followUp.ShowTab(space.Id, shown.Id).ShowSpace(space.Id);
        return navigated with { FollowUp = followUp };
    }

    /// A new tab in `placement`'s section showing `content`: a page titled by
    /// its title or host, a native view with the title and symbol it was
    /// given, or the Start Page. A saved or pinned page belongs to its address.
    private static TabState NewTab(Guid id, TabContent content, TabPlacement placement, DateTimeOffset now) {
        if (content.Address is not null && content.View is not null)
            throw new ArgumentException("A tab shows a page or a native view, not both.", nameof(content));
        var kind = content.View is { } view ? TabKind.Of(view) : content.Address is null ? TabKind.StartPage : TabKind.Web;
        var address = content.Address is { } requested ? PageAddress(requested) : null;
        var title = address is not null ? PageTitle(address, content.Title) : kind.Name;
        var native = content.View is { } shown ? new NativeTabContent(shown.Name) : null;
        return new TabState(id, title, address?.OriginalString, native, placement.IsDurable ? address?.OriginalString : null,
            kind.Symbol, FaviconUrl: null, IconAccent: null, StoredIconMode: null, placement, FolderId: null, SplitGroupId: null, now,
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
    /// again. A page put away keeps what brings it back unless the tab
    /// returns to its saved address, and the window that asked lets it go.
    public SessionEdit Handle(CloseTab intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        var edited = BrowserTabCollection.Restore(space);
        var tab = edited.Tab(intent.TabId);
        var action = TabDismissalAction.Of(tab.Placement, tab.Content.IsStartPage, space.Tabs.Count);
        if (action.ClosesWindow) throw new Rejected(new LastStartPage(tab.Id));
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        var shown = followUp.Window?.Tab(space.Id);
        Guid? selected;
        SessionTabEvents? events = null;
        if (action.KeepsTab) {
            var group = tab.SplitGroupId;
            var fallback = followUp.FallbackAfterDismissing(space.Id, tab.Id, space.Tabs
                .Where(candidate => candidate.Id != tab.Id && (group is null || candidate.SplitGroupId != group))
                .Select(candidate => candidate.Id).ToHashSet());
            var returns = ClosePolicy(turn.Basis) == SavedTabClosePolicy.ReturnToSavedUrl && (tab.SavedUrl ?? tab.Url) is not null;
            selected = edited.CloseDurable(tab.Id, shown, fallback, returns);
            events = SessionTabEvents.None with { PutAway = new(intent.WindowId, space.Id, tab.Id, KeepsState: !returns) };
        } else {
            var fallback = followUp.FallbackAfterDismissing(space.Id, tab.Id, space.Tabs.Select(candidate => candidate.Id).ToHashSet());
            selected = edited.DismissTabs([tab.Id], shown, fallback, turn.Now, deleting: false, ensureSelection: false,
                resetArchivePlacement: false);
            edited.PruneSplitMetadata();
        }
        followUp.ShowTab(space.Id, selected);
        return new(Replacing(turn.Basis, edited.Capture(space)), SyncStaging.Creation, followUp, events);
    }

    /// Deletes the tab into the archive as an open tab. The issuing window
    /// shows the tab it showed before, or the one its Space falls back to.
    public SessionEdit Handle(DeleteTab intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        var edited = BrowserTabCollection.Restore(space);
        _ = edited.Tab(intent.TabId);
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        var fallback = followUp.FallbackAfterDismissing(space.Id, intent.TabId, space.Tabs.Select(tab => tab.Id).ToHashSet());
        var selected = edited.DismissTabs([intent.TabId], followUp.Window?.Tab(space.Id), fallback, turn.Now, deleting: true,
            ensureSelection: true, resetArchivePlacement: true);
        edited.PruneSplitMetadata();
        followUp.ShowTab(space.Id, selected);
        return new(Replacing(turn.Basis, edited.Capture(space)), SyncStaging.Deletion, followUp);
    }

    /// Archives the Space's open tabs. The issuing window shows the tab it
    /// showed there when that tab stays, or the one the Space falls back to.
    public SessionEdit Handle(ClearCurrentTabs intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        var edited = BrowserTabCollection.Restore(space);
        var open = edited.Tabs.Where(tab => !tab.Placement.IsDurable).Select(tab => tab.Id).ToArray();
        if (open.Length == 0) throw new Rejected(new NoCurrentTabs(space.Id));
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        var selected = edited.DismissTabs(open, followUp.Window?.Tab(space.Id), null, turn.Now, deleting: false, ensureSelection: true,
            resetArchivePlacement: false);
        edited.PruneSplitMetadata();
        followUp.ShowTab(space.Id, selected);
        return new(Replacing(turn.Basis, edited.Capture(space)), SyncStaging.Creation, followUp);
    }

    /// Where a saved or pinned tab's page returns when it is put away. The
    /// app's preferences live in the persistent session, which every other
    /// workspace follows.
    private SavedTabClosePolicy ClosePolicy(SessionState basis) =>
        (basis.AppPreferences ?? device?.PersistentPreferences() ?? AppPreferences.Default).SavedTabClose;

    #endregion

    #region Actions - Copying and moving

    /// Copies the tab, starting from where its page is now; see
    /// `StartFromSourcePage`. The issuing window shows the copy when the
    /// intent asks.
    public SessionEdit Handle(DuplicateTab intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        var edited = BrowserTabCollection.Restore(space);
        if (edited.Tab(intent.TabId).Content.IsStartPage) throw new Rejected(new StartPageNotCopied(intent.TabId));
        var copy = edited.DuplicateTab(intent.TabId, turn.Ids, turn.Now, intent.Placement ?? TabPlacement.Current);
        StartFromSourcePage(copy, intent.TabId, intent.WindowId, turn.Pages);
        var followUp = new WindowFollowUp(IssuingWindow(intent.WindowId));
        if (intent.Shows) followUp.ShowTab(space.Id, copy.Id).ShowSpace(space.Id);
        return new(Replacing(turn.Basis, edited.Capture(space)), SyncStaging.Creation, followUp,
            new([new SessionTabCopy(intent.TabId, copy.Id)], null));
    }

    /// Moves a pinned tab to the open tabs and any other tab to the pinned
    /// tabs, each at the end of its section.
    public SessionEdit Handle(TogglePin intent, SessionTurn turn) {
        var pinned = Editable(turn.Basis, intent.SpaceId).Tabs.FirstOrDefault(tab => tab.Id == intent.TabId)?.Placement == TabPlacement.Pinned;
        return Handle(new MoveTab(intent.WorkspaceId, intent.SpaceId, intent.TabId,
            pinned ? TabPlacement.Current : TabPlacement.Pinned, FolderId: null, BeforeTabId: null, LeavesSplit: false), turn);
    }

    /// Moves the tab, which leaves its split for a section that holds none.
    /// One that leaves its split takes the split's metadata with it when no
    /// other tab keeps it.
    public SessionEdit Handle(MoveTab intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => {
            bool leaves = intent.LeavesSplit || !intent.Placement.HoldsSplits;
            edited.MoveTab(intent.TabId, intent.Placement, intent.FolderId, intent.BeforeTabId, leaves, turn.Now);
            if (leaves) edited.PruneSplitMetadata();
        });

    #endregion
}
