namespace CrestCore.Contracts;

/// The page's media session as Crest shows it for `Document`: what plays, how,
/// and what it can be asked to do. `Sequence` counts up with each change so a
/// late one never replaces a newer one.
public sealed record MediaSessionChanged(Guid PageId, string Document, long Sequence, string Location, bool Active,
    string? Title, string? Artist, string? Album, MediaPlayback Playback, bool Audible, bool Muted,
    IReadOnlyList<MediaSessionAction> Actions) : EnginePresentation;
