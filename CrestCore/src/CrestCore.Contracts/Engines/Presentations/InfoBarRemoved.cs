namespace CrestCore.Contracts;

/// The bar `InfoBarShown` presented is gone.
public sealed record InfoBarRemoved(Guid PageId, int InfoBarId) : EnginePresentation;
