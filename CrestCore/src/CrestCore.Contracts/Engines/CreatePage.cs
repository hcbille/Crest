namespace CrestCore.Contracts;

/// Creates the engine's page for a page the core opened, in the profile of the
/// page's Space, hosted by the window `WindowId` names. A private page keeps
/// nothing once it closes. It borrows the regular profile `BorrowedProfileId`
/// names, from which an engine that derives private profiles, as Chromium
/// does, takes settings and the extensions allowed in private browsing but no
/// data; with none named, it derives from a profile no Space owns. See
/// `OpenPrivateBrowsing`. `RestoreState` is what an earlier page of the same
/// tab kept, which the new page restores instead of loading anew. The binding
/// answers with `PageCreated` or `PageCreationFailed`.
public sealed record CreatePage(Guid PageId, Guid ProfileId, bool IsPrivate, Guid? BorrowedProfileId, Guid WindowId,
    PageRestoreState? RestoreState) : EngineCommand;
