namespace CrestCore.Contracts;

/// Creates the engine's page for a page the core opened, in the profile of the
/// page's Space, hosted by the window `WindowId` names. A private page keeps
/// nothing once it closes. `RestoreState` is what an earlier page of the same
/// tab kept, which the new page restores instead of loading anew. The binding
/// answers with `PageCreated` or `PageCreationFailed`.
public sealed record CreatePage(Guid PageId, Guid ProfileId, bool IsPrivate, Guid WindowId, PageRestoreState? RestoreState)
    : EngineCommand;
