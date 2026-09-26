using CrestCore.Contracts;

namespace CrestCore.Domain;

/// How a page's blocked-popup notice moves with each popup event.
public static class BlockedPopupPolicy {
    #region Actions - Popups

    /// The state after `popupEvent`, or null when it changes nothing. An event
    /// that starts an indication needs the document identifier and the blocked
    /// site's origin, a state names a status and an origin together or
    /// neither, and every origin must be one the rules can read; otherwise
    /// `InvalidBlockedPopup`.
    public static BlockedPopupPageState? Apply(BlockedPopupPageState state, BlockedPopupEvent popupEvent, string? documentIdentifier,
        SiteOrigin? origin) {
        ArgumentNullException.ThrowIfNull(state);
        ArgumentNullException.ThrowIfNull(popupEvent);
        if ((state.Status is null) != (state.Origin is null) || state.Origin is { IsValid: false } || origin is { IsValid: false }
            || state.DocumentIdentifier is { Length: > BlockedPopupPageState.MaximumDocumentIdentifierLength }
            || popupEvent.StartsIndication && (string.IsNullOrEmpty(documentIdentifier)
                || documentIdentifier.Length > BlockedPopupPageState.MaximumDocumentIdentifierLength || origin is null))
            throw new Rejected(new InvalidBlockedPopup());
        bool applies = popupEvent.FromAnything ? state.Status is not null || state.DocumentIdentifier is not null : state.Status == popupEvent.From;
        if (!applies) return null;
        if (popupEvent.StartsIndication) return new(popupEvent.To, origin, documentIdentifier, unchecked(state.IndicationRevision + 1));
        return popupEvent.To is { } status
            ? state with { Status = status }
            : state with { Status = null, Origin = null, DocumentIdentifier = null };
    }

    #endregion
}
