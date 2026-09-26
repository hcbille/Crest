namespace CrestCore.Contracts;

/// A data deletion ended: `Deleted` says every registered engine erased what
/// it was asked to.
public sealed record DataDeleted(Guid RequestId, bool Deleted) : Change;
