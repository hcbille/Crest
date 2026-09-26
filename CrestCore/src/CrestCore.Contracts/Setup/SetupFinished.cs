namespace CrestCore.Contracts;

/// Setup over the workspace finished. The platform opens the Getting Started
/// guide in `GuideSpaceId`, the workspace's first Space, when it names one.
public sealed record SetupFinished(Guid WorkspaceId, Guid? GuideSpaceId) : Change;
