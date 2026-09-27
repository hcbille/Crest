namespace CrestCore.Contracts;

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
