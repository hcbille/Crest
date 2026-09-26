namespace CrestCore.Contracts;

/// Prepares to close the pages `PageIds` names, in that order.
public sealed record PrepareToClosePages(Guid RequestId, IReadOnlyList<Guid> PageIds) : CloseIntent(RequestId);
