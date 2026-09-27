using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

internal sealed partial class NativeSessionAuthority {
    #region Variables

    /// What a folder created without a title is called.
    private const string NewFolderTitle = "New Folder";

    #endregion

    #region Actions - Folders

    /// Creates the folder and files its tabs in one edit.
    public SessionEdit Handle(CreateFolder intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Creation, edited => {
            edited.AddFolder(intent.FolderId, string.IsNullOrWhiteSpace(intent.Title) ? NewFolderTitle : intent.Title,
                intent.Placement, intent.ParentId);
            if (intent.Color is { } color) edited.SetFolderColor(intent.FolderId, color);
            if (intent.Symbol is { } symbol) edited.SetFolderSymbol(intent.FolderId, symbol);
            if (intent.TabIds.Count > 0)
                edited.FileTabs(intent.TabIds, intent.Placement, intent.FolderId, turn.Now, null, null, intent.LeavesSplits);
        });

    public SessionEdit Handle(RenameFolder intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => edited.RenameFolder(intent.FolderId, intent.Title));

    public SessionEdit Handle(CollapseFolder intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => edited.CollapseFolder(intent.FolderId, intent.Collapsed, turn.Now));

    public SessionEdit Handle(SetFolderColor intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => edited.SetFolderColor(intent.FolderId, intent.Color));

    public SessionEdit Handle(SetFolderSymbol intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => edited.SetFolderSymbol(intent.FolderId, intent.Symbol));

    public SessionEdit Handle(MoveFolder intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited =>
            edited.MoveFolder(intent.FolderId, intent.Placement, intent.ParentId, turn.Now, intent.BeforeFolderId, intent.BeforeTabId));

    public SessionEdit Handle(DeleteFolder intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Deletion, edited => edited.DeleteFolder(intent.FolderId, turn.Now));

    /// Files the selection, saved with its journal before the intent returns
    /// as every action on a selection is. Tabs taken out of their splits
    /// leave split metadata no tab uses, which goes with them.
    public SessionEdit Handle(FileTabs intent, SessionTurn turn) {
        var batch = Selecting(turn.Basis, intent.WindowId, intent.SpaceId, intent.Selection);
        batch.Edited.FileSelected(batch.Selected, intent.Placement, intent.FolderId, intent.BeforeTabId, intent.BeforeFolderId,
            intent.LeavesSplits, turn.Now);
        return batch.Result(turn.Basis, SyncStaging.Batch);
    }

    #endregion

    #region Actions - Splits

    public SessionEdit Handle(JoinSplit intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        return Joining(turn.Basis, space, BrowserTabCollection.Restore(space), intent.WindowId, intent.TabId, intent.TargetTabId,
            intent.Index, turn.Pages, turn.Now, turn.Ids);
    }

    /// Opens the link as a new open tab and joins it to the target's split.
    public SessionEdit Handle(OpenLinkInSplit intent, SessionTurn turn) {
        var space = Editable(turn.Basis, intent.SpaceId);
        if (turn.Basis.Spaces.Any(candidate => candidate.Tabs.Any(tab => tab.Id == intent.TabId)))
            throw new Rejected(new TabAlreadyExists(intent.TabId));
        var edited = BrowserTabCollection.Restore(space);
        edited.InsertTab(BrowserTab.Restore(new TabState(intent.TabId, intent.Title, intent.Address, NativeContent: null,
            SavedUrl: null, TabIconMode.WebSymbol, FaviconUrl: null, IconAccent: null, StoredIconMode: null, TabPlacement.Current,
            FolderId: null, SplitGroupId: null, turn.Now, PositionModifiedAt: null, CustomTitle: null, TitleModifiedAt: null,
            KeepsPageLoaded: false)), null);
        return Joining(turn.Basis, space, edited, intent.WindowId, intent.TabId, intent.TargetTabId, null, turn.Pages, turn.Now, turn.Ids);
    }

    /// Joins `tabId` to the split of `targetId` in `edited`, the organization
    /// of `space`, and shows the joined tab in the issuing window. A copy
    /// starts from where its source's page is now; see `StartFromSourcePage`.
    /// A durable target's split copied into new tabs keeps its name, icon and
    /// tint.
    private SessionEdit Joining(SessionState basis, SpaceState space, BrowserTabCollection edited, Guid windowId, Guid tabId, Guid targetId,
        int? index, Pages? pages, DateTimeOffset now, IIdSource ids) {
        var target = edited.Tab(targetId);
        var durableGroup = target.Placement.IsDurable ? target.SplitGroupId : null;
        var joined = edited.JoinSplit(tabId, targetId, index, ids, now);
        foreach (var (source, copyId) in joined.Copies) StartFromSourcePage(edited.Tab(copyId), source, windowId, pages);
        if (durableGroup is { } copied && joined.Copies.Any(pair => pair.Source == targetId)
            && edited.Tab(joined.SelectedTab).SplitGroupId is { } copy)
            edited.CopySplitMetadata(copied, copy, now);
        edited.PruneSplitMetadata();
        var followUp = new WindowFollowUp(IssuingWindow(windowId)).ShowTab(space.Id, joined.SelectedTab).ShowSpace(space.Id);
        return new(Replacing(basis, edited.Capture(space)), SyncStaging.Edit, followUp,
            new([.. joined.Copies.Select(pair => new SessionTabCopy(pair.Source, pair.Copy))], null));
    }

    public SessionEdit Handle(LeaveSplit intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => {
            edited.LeaveSplit(intent.TabId, turn.Now);
            edited.PruneSplitMetadata();
        });

    public SessionEdit Handle(MoveSplitMember intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => edited.MoveSplitMember(intent.TabId, intent.Index, turn.Now));

    public SessionEdit Handle(StepSplitMember intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => {
            if (!edited.StepSplitMember(intent.TabId, intent.Offset, turn.Now)) throw new Rejected(new NoSplitStep(intent.TabId, intent.Offset));
        });

    public SessionEdit Handle(DissolveSplit intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => {
            edited.DissolveSplit(intent.GroupId, turn.Now);
            edited.PruneSplitMetadata();
        });

    public SessionEdit Handle(MoveSplit intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited =>
            edited.MoveSplitGroup(intent.GroupId, intent.Placement, intent.FolderId, intent.BeforeTabId, turn.Now));

    /// `space`'s organization after `edit`, with the Space's other records kept.
    private SessionEdit Organizing(SessionState basis, Guid spaceId, SyncStaging staging, Action<BrowserTabCollection> edit) {
        var space = Editable(basis, spaceId);
        var edited = BrowserTabCollection.Restore(space);
        edit(edited);
        return new(Replacing(basis, edited.Capture(space)), staging);
    }

    #endregion

    #region Actions - Split identity

    /// A blank name clears it; a name is kept trimmed.
    public SessionEdit Handle(NameSplit intent, SessionTurn turn) =>
        Identifying(turn.Basis, intent.SpaceId, intent.GroupId, turn.Now, group =>
            group with { CustomTitle = string.IsNullOrWhiteSpace(intent.Name) ? null : intent.Name.Trim() },
            (group, changedAt) => group with { TitleModifiedAt = changedAt });

    /// An emoji icon is kept as the one character that presents as an emoji.
    public SessionEdit Handle(SetSplitIcon intent, SessionTurn turn) {
        string? symbol = intent.Emoji is null ? null
            : (EmojiIcon.Chosen(intent.Emoji) ?? throw new Rejected(new InvalidSplitIcon(intent.GroupId))).Symbol;
        return Identifying(turn.Basis, intent.SpaceId, intent.GroupId, turn.Now, group => group with { CustomIconSymbol = symbol },
            (group, changedAt) => group with { IconModifiedAt = changedAt });
    }

    public SessionEdit Handle(TintSplit intent, SessionTurn turn) =>
        Identifying(turn.Basis, intent.SpaceId, intent.GroupId, turn.Now, group => group with { Tint = intent.Tint },
            (group, changedAt) => group with { TintModifiedAt = changedAt });

    /// A split's name, icon or tint, which only a split of two or more tabs
    /// has. `choose` sets the field; `stamp` records when, so each field merges
    /// on its own. A choice that is already the split's changes nothing.
    private SessionEdit Identifying(SessionState basis, Guid spaceId, Guid groupId, DateTimeOffset now,
        Func<SplitGroupState, SplitGroupState> choose, Func<SplitGroupState, DateTimeOffset, SplitGroupState> stamp) {
        var space = Editable(basis, spaceId);
        var run = space.Tabs.SkipWhile(tab => tab.SplitGroupId != groupId).TakeWhile(tab => tab.SplitGroupId == groupId);
        if (run.Take(2).Count() < 2) throw new Rejected(new UnknownSplitGroup(groupId));
        var existing = space.SplitGroups.FirstOrDefault(group => group.Id == groupId);
        var current = existing ?? new SplitGroupState(groupId);
        var chosen = choose(current);
        if (chosen == current) return new(basis, SyncStaging.Edit);
        var edited = stamp(chosen, BrowserEditTimestamp.Normalize(now));
        IReadOnlyList<SplitGroupState> groups = existing is null ? [.. space.SplitGroups, edited]
            : [.. space.SplitGroups.Select(candidate => candidate.Id == groupId ? edited : candidate)];
        return new(Replacing(basis, space with { SplitGroups = groups }), SyncStaging.Edit);
    }

    #endregion
}
