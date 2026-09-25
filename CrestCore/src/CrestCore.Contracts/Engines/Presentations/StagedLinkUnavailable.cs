namespace CrestCore.Contracts;

/// A link staged for the page's first load no longer applies, so the page did
/// not load it. TRANSITIONAL until link routing moves to the core (WP C (l)).
public sealed record StagedLinkUnavailable(Guid PageId) : EnginePresentation;
