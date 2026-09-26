namespace CrestCore.Contracts;

/// Asks a page whether it may go: its document may ask the person to stay.
/// The binding answers with `BeforeUnloadAnswered`, at once for a document
/// that asks nothing.
public sealed record CheckBeforeUnload(Guid PageId) : EngineCommand;
