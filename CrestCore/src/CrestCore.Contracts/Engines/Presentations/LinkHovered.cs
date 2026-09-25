namespace CrestCore.Contracts;

/// The link under the pointer in the page, or none when the pointer left it.
public sealed record LinkHovered(Guid PageId, string? Url) : EnginePresentation;
