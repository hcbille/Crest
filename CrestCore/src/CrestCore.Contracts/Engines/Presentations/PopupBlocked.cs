namespace CrestCore.Contracts;

/// The engine blocked a pop-up the document at `PageUrl` opened.
public sealed record PopupBlocked(Guid PageId, string PageUrl) : EnginePresentation;
