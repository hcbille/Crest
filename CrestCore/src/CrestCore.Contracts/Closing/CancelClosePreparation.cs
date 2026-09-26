namespace CrestCore.Contracts;

/// Stops the preparation `RequestId` names, which ends not allowed. Nothing
/// happens when another preparation, or none, is under way.
public sealed record CancelClosePreparation(Guid RequestId) : CloseIntent(RequestId);
