namespace CrestCore.Contracts;

/// A request to close pages, windows or the app, which the core prepares by
/// asking each page it would close whether it may go. One preparation runs at
/// a time, and ends with `CloseReady`. TRANSITIONAL: the platform still runs
/// the Chromium shell's preflight until its close and quit wiring moves here.
public abstract record CloseIntent(Guid RequestId) : Intent;
