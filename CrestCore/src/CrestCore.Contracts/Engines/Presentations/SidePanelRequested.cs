namespace CrestCore.Contracts;

/// The engine asks for the extension's side panel beside the page: its
/// `chrome.sidePanel.open()` or `close()`, or an action click that toggles
/// the panel instead of opening a popup. A panel is a card beside the page,
/// so the engine never opens or closes one itself.
public sealed record SidePanelRequested(Guid PageId, string ExtensionId, SidePanelRequest Request)
    : EnginePresentation;
