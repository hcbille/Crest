using CrestCore.Contracts;

namespace CrestCore.Application;

/// Which regular profile each private workspace's pages borrow. An engine
/// such as Chromium derives a private profile from a regular one, sharing its
/// settings and the extensions allowed in private browsing, never its data.
/// A private workspace borrows the profile of the Space shown by the window
/// private browsing last opened from, while that Space is held, unlocked and
/// not being deleted; otherwise it borrows none, and the engine derives its
/// private profile from one no Space owns. Kept in memory only.
internal sealed partial class Device {
    #region Variables

    /// Where each private workspace last opened from, by private workspace:
    /// the workspace of the window it opened from and the Space that window
    /// showed.
    private readonly Dictionary<Guid, (Guid WorkspaceId, Guid SpaceId)> privateOrigins = [];

    #endregion

    #region Actions - Private browsing intents

    private void Open(OpenPrivateBrowsing intent) {
        var window = Opened(intent.WindowId);
        var from = Opened(intent.FromWindowId);
        if (!Workspace(window.WorkspaceId).Kind.IsPrivate) throw new Rejected(new NotPrivateWorkspace(window.WorkspaceId));
        var lends = !Workspace(from.WorkspaceId).Kind.IsPrivate;
        lock (gate) {
            if (lends) privateOrigins[window.WorkspaceId] = (from.WorkspaceId, from.ShownSpaceId);
            else privateOrigins.Remove(window.WorkspaceId);
        }
    }

    #endregion

    #region Actions - Private browsing queries

    /// The regular profile the private workspace `workspaceId`'s pages borrow
    /// now, or null when it borrows none. Called without the device lock,
    /// since it reads the sessions.
    public Guid? BorrowedProfile(Guid workspaceId) {
        (Guid WorkspaceId, Guid SpaceId) origin;
        NativeSessionAuthority? lender;
        lock (gate) {
            if (!privateOrigins.TryGetValue(workspaceId, out origin)) return null;
            lender = workspaces.GetValueOrDefault(origin.WorkspaceId);
        }
        if (lender is null || lender.IsDeleting(origin.SpaceId)) return null;
        var space = lender.Current.Spaces.FirstOrDefault(candidate => candidate.Id == origin.SpaceId);
        return space is null || lender.IsLocked(space) ? null : space.ProfileId;
    }

    #endregion
}
