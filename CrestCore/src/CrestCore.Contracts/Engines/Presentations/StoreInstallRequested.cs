namespace CrestCore.Contracts;

/// The Chrome Web Store listing the page shows asked to install the extension
/// it is about. The engine checked the listing names `ExtensionId`.
public sealed record StoreInstallRequested(Guid PageId, string ExtensionId) : EnginePresentation;
