using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// A page's blocked-popup notice after one popup event from `State`. Refused
/// with `InvalidBlockedPopup` for a state or event the notice cannot hold.
public sealed record BlockedPopupTransition(BlockedPopupPageState State, BlockedPopupEvent Event, string? DocumentIdentifier,
    SiteOrigin? Origin) : StandaloneQuery<BlockedPopupTransitioned> {
    #region Actions - Answering

    internal override BlockedPopupTransitioned Answer(StandaloneContext context) =>
        new(BlockedPopupPolicy.Apply(State, Event, DocumentIdentifier, Origin));

    #endregion
}
