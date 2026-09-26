namespace CrestCore.Contracts;

/// A blocked-popup state or event the notice cannot hold: a status without an
/// origin or the reverse, or an indication without its document or origin.
public sealed record InvalidBlockedPopup : Rejection;
