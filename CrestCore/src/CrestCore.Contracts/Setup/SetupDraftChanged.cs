namespace CrestCore.Contracts;

/// The manual setup this device holds changed, or ended when `Draft` is null.
public sealed record SetupDraftChanged(SetupDraft? Draft) : Change;
