namespace CrestCore.Contracts;

/// The page's latest find counted `Matches` matches and selected the
/// `ActiveMatch`th, counted from 1; none found when `Matches` is 0. An engine
/// that finds a match but cannot count them leaves `Matches` null.
public sealed record FindFinished(Guid PageId, int? Matches, int ActiveMatch) : EnginePresentation;
