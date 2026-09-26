namespace CrestCore.Contracts;

/// Brings back the document a page showed when its renderer stopped, as the
/// core's crash recovery decided. The binding loads the page's current history
/// entry again, never posting a form a second time, and reports the navigation
/// it starts as it reports any other.
public sealed record RecoverPage(Guid PageId) : EngineCommand;
