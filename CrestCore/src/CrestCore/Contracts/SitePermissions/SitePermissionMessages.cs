namespace CrestCore.Contracts;

#region Intents

/// An intent about this device's site permission choices. The device store
/// keeps the persistent session's choices beside the session, never in it,
/// and they never sync; every other Space's choices live in memory until the
/// process ends.
public abstract record SitePermissionIntent : Intent;

/// Carries the site permission choices an installed release kept in its
/// defaults into the device store, once, and publishes every Space's choices.
/// `Records` is the document that release saved under
/// `crest.site-permissions.v1`, or null when it saved none. Entries this build
/// cannot read, repeats of an earlier choice and anything but a persistent
/// answer are left out. The store is written before the intent returns; a
/// device that adopted them before, or keeps no file, adopts nothing and still
/// publishes what it holds.
public sealed record AdoptSitePermissions(byte[]? Records) : SitePermissionIntent;

/// Records the person's answer for `Permission` at `Origin` in a Space.
/// `Detail` narrows a capability a site can ask for more than one way, such as
/// the URL scheme behind one external-app hand-off; null is the site-wide rule.
/// Ask clears both the session and the saved choice; a session answer
/// overrides the saved choice until the process ends without replacing it; a
/// persistent answer replaces both and keeps an existing record's identity.
public sealed record DecideSitePermission(Guid SpaceId, SiteOrigin Origin, SitePermission Permission, string? Detail,
    SitePermissionDecision Decision) : SitePermissionIntent;

/// Forgets one saved choice, so the site asks again. A locked Space's choice
/// is forgotten too; a record that is gone changes nothing.
public sealed record ResetSitePermission(Guid RecordId) : SitePermissionIntent;

/// Forgets every saved and session choice in one Space, locked, deleted or
/// private alike, so resetting or deleting a Space is never blocked.
public sealed record ResetSpacePermissions(Guid SpaceId) : SitePermissionIntent;

#endregion

#region Queries

/// A page's blocked-popup notice after one popup event from `State`. Refused
/// with `InvalidBlockedPopup` for a state or event the notice cannot hold.
public sealed record BlockedPopupTransition(BlockedPopupPageState State, BlockedPopupEvent Event, string? DocumentIdentifier,
    SiteOrigin? Origin) : StandaloneQuery<BlockedPopupTransitioned>;

/// The page's popup state after the event, or null when the event changed
/// nothing and the page keeps its state and shows no new indication.
public sealed record BlockedPopupTransitioned(BlockedPopupPageState? State);

/// The choice that answers a request to capture `Media` at `Origin` in a
/// Space. Combined capture respects a block on any of its devices, and a
/// combined grant still answers a request for one of them; a capability that
/// stands alone answers as `SiteDecision` does. A locked Space, and an origin
/// the rules cannot read, answer Ask.
public sealed record CaptureDecision(Guid SpaceId, SiteOrigin Origin, SitePermission Media) : Query<SitePermissionAnswer>;

/// The choice that answers a site permission question.
public sealed record SitePermissionAnswer(SitePermissionDecision Decision);

/// What a page's request to post notifications leads to, given the saved
/// decision for its site and whether a person's gesture started it.
public sealed record NotificationPermissionRequest(SitePermissionDecision Decision, bool HasUserActivation)
    : StandaloneQuery<NotificationRequestAnswer>;

/// What the notification request leads to.
public sealed record NotificationRequestAnswer(HostedNotificationRequestAction Action);

/// Whether a site may use a capability that needs a secure origin, such as
/// location or hosted notifications, at all.
public sealed record SecureOriginCheck(SiteOrigin Origin) : StandaloneQuery<SecureOriginVerdict>;

/// Whether the origin is secure enough for the capability.
public sealed record SecureOriginVerdict(bool Allowed);

/// The choice that answers one request for `Permission` at `Origin` in a
/// Space: the session choice, then the saved one, for `Detail` first and then
/// for the whole site. A locked Space, and an origin or detail the rules
/// cannot read, answer Ask.
public sealed record SiteDecision(Guid SpaceId, SiteOrigin Origin, SitePermission Permission, string? Detail)
    : Query<SitePermissionAnswer>;

#endregion

#region Changes

/// A Space's site permission choices changed. `Records` are the choices it
/// keeps now, in the order the settings list them; `Touched` names what the
/// change covered, so a page can withdraw what it was already given.
public sealed record SitePermissionsChanged(Guid SpaceId, IReadOnlyList<SitePermissionRecordState> Records,
    IReadOnlyList<SitePermissionScope> Touched) : Change;

/// Which choices in a Space one change covered. A null member covers every
/// value, so a Space reset names none. `RevokesAuthorization` tells live pages
/// to withdraw what they were already given.
public sealed record SitePermissionScope(SiteOrigin? Origin, SitePermission? Permission, string? Detail,
    bool RevokesAuthorization);

#endregion

#region Rejections

/// A blocked-popup state or event the notice cannot hold: a status without an
/// origin or the reverse, or an indication without its document or origin.
public sealed record InvalidBlockedPopup : Rejection;

/// A site permission's origin has an empty or overlong scheme or host, or a
/// port that is not one.
public sealed record InvalidSiteOrigin(SiteOrigin Origin) : Rejection;

/// A choice's detail is empty or longer than `Limit` characters.
public sealed record InvalidSitePermissionDetail(int Limit) : Rejection;

/// This device already keeps `Limit` saved site permission choices.
public sealed record SitePermissionLimitReached(int Limit) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized(Argument = nameof(Limit))]
    public string Message => "Crest can keep up to %lld saved site permissions. Reset some to save more.";

    #endregion
}

#endregion

#region Models

/// What a site permission decision says about a request: let it through, stop
/// it, or ask the person.
public enum SitePermissionVerdict { Ask, Grant, Deny }

#endregion
