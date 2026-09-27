namespace CrestCore.Contracts;

#region Intents

/// Adds a custom search engine to a Space, trimmed and validated, after the
/// others, and searches with it when `Selects`.
public sealed record AddSearchEngine(Guid WorkspaceId, Guid SpaceId, CustomSearchEngine Engine, bool Selects)
    : SessionIntent(WorkspaceId);

/// Removes one of a Space's custom search engines. A Space that searched with
/// it searches with Google.
public sealed record RemoveSearchEngine(Guid WorkspaceId, Guid SpaceId, Guid EngineId) : SessionIntent(WorkspaceId);

/// Makes a Space search with a built-in engine or with one of its custom
/// engines; exactly one of `BuiltIn` and `CustomEngineId` names it.
public sealed record SelectSearchEngine(Guid WorkspaceId, Guid SpaceId, BuiltInSearchEngine? BuiltIn, Guid? CustomEngineId)
    : SessionIntent(WorkspaceId);

/// Replaces one of a Space's custom search engines, which keeps its place and
/// may keep its own name.
public sealed record UpdateSearchEngine(Guid WorkspaceId, Guid SpaceId, CustomSearchEngine Engine) : SessionIntent(WorkspaceId);

#endregion

#region Rejections

/// The Space has no usable custom search engine with this identity, or the
/// intent named no engine or two.
public sealed record UnknownSearchEngine(Guid? EngineId) : Rejection;

#endregion
