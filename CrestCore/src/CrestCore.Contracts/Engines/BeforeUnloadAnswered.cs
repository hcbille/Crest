namespace CrestCore.Contracts;

/// Whether a page the core asked may go.
public sealed record BeforeUnloadAnswered(Guid PageId, bool Proceeds) : EngineEvent;
