namespace CrestCore.Contracts;

/// Moves a page to `Engine`. The core closes the page on its engine, keeping
/// nothing, creates it on `Engine` in the same profile and window, and once
/// that engine has created it, loads the address the page showed. The page
/// keeps its identity, its owner and its window; its history, form state and
/// anything its old engine kept stay behind. A page already on `Engine`
/// stays. Refused when the page is not open, its Space is locked or being
/// deleted, or this device did not register `Engine`.
public sealed record RehostPage(Guid PageId, EngineKind Engine) : PageIntent;
