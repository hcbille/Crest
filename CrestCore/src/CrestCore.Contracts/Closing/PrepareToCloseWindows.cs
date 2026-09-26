namespace CrestCore.Contracts;

/// Prepares to close the windows `WindowIds` names, with every page they host.
public sealed record PrepareToCloseWindows(Guid RequestId, IReadOnlyList<Guid> WindowIds) : CloseIntent(RequestId);
