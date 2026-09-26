namespace CrestCore.Contracts;

/// The engine opened a page of its own — a script's `window.open`, a link to a
/// new window, an extension's `chrome.windows.create` — in the profile
/// `ProfileId` names, beside the page `SourcePageId` names or in the engine
/// window `WindowId` names that Crest reserved for the Space `SpaceId` names.
/// The core adopts it as a tab with `AdoptOfferedPage` or refuses it with
/// `RejectOfferedPage`. TRANSITIONAL until engine-offered pages move to the
/// core (WP C (l)).
public sealed record PageOffered(Guid AdoptionId, Guid ProfileId, Guid? WindowId, Guid? SpaceId, Guid? SourcePageId,
    string Url, bool Foreground) : EnginePresentation;
