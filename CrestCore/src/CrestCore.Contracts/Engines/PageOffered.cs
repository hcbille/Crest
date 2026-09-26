namespace CrestCore.Contracts;

/// The engine opened a page of its own in the profile `ProfileId` names: a
/// script's `window.open`, a link to a new window or tab, or an extension's
/// tab. `SourcePageId` names the page that opened it, when one did. Otherwise
/// `WindowId` names the Crest window whose engine window holds it, and
/// `SpaceId` the Space a window the engine created for itself was reserved
/// for. `Url` is where it is heading, and `Foreground` whether the engine
/// brought it to the front. The core adopts it with `AdoptOfferedPage` or
/// refuses it with `RejectOfferedPage`.
public sealed record PageOffered(Guid OfferId, Guid ProfileId, Guid? SourcePageId, Guid? WindowId, Guid? SpaceId, string Url,
    bool Foreground) : EngineEvent;
