namespace CrestCore.Contracts;

/// The Chrome Web Store listing the page shows asked to remove the extension
/// it is about. The engine checked the listing names `ExtensionId`.
public sealed record StoreRemovalRequested(Guid PageId, string ExtensionId) : EnginePresentation;
