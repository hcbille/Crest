namespace CrestCore.Contracts;

/// The deletion `DeleteProfile` began finished, or could not finish.
public sealed record ProfileDeleted(Guid DeletionId, bool Deleted) : EnginePresentation;
