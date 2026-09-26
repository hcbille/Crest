namespace CrestCore.Contracts;

/// Prepares to quit: every page this device hosts may go, and the person
/// agrees to stop the downloads still in progress.
public sealed record PrepareToQuit(Guid RequestId) : CloseIntent(RequestId);
