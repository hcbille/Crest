namespace CrestCore.Contracts;

/// The Space `SpaceId`, where the Getting Started guide opens, is locked.
public sealed record GuideSpaceLocked(Guid SpaceId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Unlock your first Space to open Getting Started.";

    #endregion
}
