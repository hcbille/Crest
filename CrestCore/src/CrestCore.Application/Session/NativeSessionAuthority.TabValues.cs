using CrestCore.Contracts;

namespace CrestCore.Application;

internal sealed partial class NativeSessionAuthority {
    #region Actions - Tab values

    public SessionEdit Handle(RenameTab intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => edited.Tab(intent.TabId).Rename(intent.Title, turn.Now));

    /// A tab that pulls its page's favicon wears the image the issuer offered,
    /// and any other choice drops its image. The assignment is published even
    /// when the choice changes nothing else, so a favicon pulled again from the
    /// same page replaces the image the tab wears.
    public SessionEdit Handle(ChooseTabIcon intent, SessionTurn turn) {
        var adopts = false;
        var edit = Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited =>
            adopts = edited.Tab(intent.TabId).ChooseIcon(intent.Mode, intent.Emoji, intent.Accent));
        return edit with { Events = new([], new SessionFaviconUpdate(intent.TabId, adopts)) };
    }

    public SessionEdit Handle(ReplaceSavedAddress intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => edited.Tab(intent.TabId).ReplaceSavedAddress());

    public SessionEdit Handle(ReturnToSavedAddress intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => edited.Tab(intent.TabId).ReturnToSavedAddress());

    public SessionEdit Handle(KeepPageLoaded intent, SessionTurn turn) =>
        Organizing(turn.Basis, intent.SpaceId, SyncStaging.Edit, edited => edited.Tab(intent.TabId).SetResidency(intent.Keeps));

    #endregion
}
