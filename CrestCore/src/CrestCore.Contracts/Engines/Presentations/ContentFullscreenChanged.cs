namespace CrestCore.Contracts;

/// The page's content entered or left fullscreen. The page still owns its
/// fullscreen and leaves it on Escape.
public sealed record ContentFullscreenChanged(Guid PageId, bool Active) : EnginePresentation;
