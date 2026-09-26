namespace CrestCore.Contracts;

/// A page's blocked-popup notice after one popup event from `State`. Refused
/// with `InvalidBlockedPopup` for a state or event the notice cannot hold.
public sealed record BlockedPopupTransition(BlockedPopupPageState State, BlockedPopupEvent Event, string? DocumentIdentifier,
    SiteOrigin? Origin) : Query<BlockedPopupTransitioned>;
