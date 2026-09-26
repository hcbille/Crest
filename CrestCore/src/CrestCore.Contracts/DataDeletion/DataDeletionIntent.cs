namespace CrestCore.Contracts;

/// A request to erase what the engines keep for a profile, which the core asks
/// of every registered engine, started or not. It ends with `DataDeleted`.
public abstract record DataDeletionIntent(Guid RequestId) : Intent;
