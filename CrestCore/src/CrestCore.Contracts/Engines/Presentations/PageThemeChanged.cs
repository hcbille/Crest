namespace CrestCore.Contracts;

/// The colour the page's document declared for its surroundings, or none.
public sealed record PageThemeChanged(Guid PageId, BrandColor? Color) : EnginePresentation;
