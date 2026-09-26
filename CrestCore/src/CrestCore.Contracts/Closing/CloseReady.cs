namespace CrestCore.Contracts;

/// A close preparation ended: `Allowed` says every page it asked about may go
/// and still shows the document that agreed, and, for a quit, that the person
/// agreed to stop the downloads in progress.
public sealed record CloseReady(Guid RequestId, bool Allowed) : Change;
