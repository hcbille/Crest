namespace CrestCore.Contracts;

/// The page's popup state after the event, or null when the event changed
/// nothing and the page keeps its state and shows no new indication.
public sealed record BlockedPopupTransitioned(BlockedPopupPageState? State);
