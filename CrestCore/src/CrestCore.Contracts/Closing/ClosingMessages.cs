namespace CrestCore.Contracts;

#region Intents

/// A request to close pages, windows or the app, which the core prepares by
/// asking each page it would close whether it may go. One preparation runs at
/// a time, and ends with `CloseReady`.
public abstract record CloseIntent(Guid RequestId) : Intent;

/// Whether the person quits and stops the downloads in progress.
public sealed record AnswerQuitWithDownloads(Guid PromptId, bool Quits) : PromptIntent(PromptId);

/// Stops the preparation `RequestId` names, which ends not allowed. Nothing
/// happens when another preparation, or none, is under way.
public sealed record CancelClosePreparation(Guid RequestId) : CloseIntent(RequestId);

/// Prepares to close the pages `PageIds` names, in that order.
public sealed record PrepareToClosePages(Guid RequestId, IReadOnlyList<Guid> PageIds) : CloseIntent(RequestId);

/// Prepares to close the windows `WindowIds` names, with every page they host.
public sealed record PrepareToCloseWindows(Guid RequestId, IReadOnlyList<Guid> WindowIds) : CloseIntent(RequestId);

/// Prepares to quit: every page this device hosts may go, and the person
/// agrees to stop the downloads still in progress.
public sealed record PrepareToQuit(Guid RequestId) : CloseIntent(RequestId);

#endregion

#region Changes

/// A close preparation ended: `Allowed` says every page it asked about may go
/// and still shows the document that agreed, and, for a quit, that the person
/// agreed to stop the downloads in progress.
public sealed record CloseReady(Guid RequestId, bool Allowed) : Change;

/// Whether to quit and stop the `LiveDownloads` downloads still in progress
/// waits on the person, for the quit preparation `RequestId`.
public sealed record QuitWithDownloadsAsked(Guid PromptId, Guid RequestId, int LiveDownloads) : Change;

#endregion

#region Rejections

/// Another close preparation, `RequestId`, is still under way.
public sealed record ClosePreparationUnderway(Guid RequestId) : Rejection;

#endregion
