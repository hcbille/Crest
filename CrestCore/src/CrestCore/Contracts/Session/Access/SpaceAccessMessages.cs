namespace CrestCore.Contracts;

#region Intents

/// Starts unlocking a Space of a workspace as the request `RequestId`, which
/// the platform answers once the device owner has authenticated or declined.
/// One request waits at a time. A Space that opens freely, or that this
/// process already unlocked, needs no request and changes nothing.
public sealed record BeginUnlockingSpace(Guid WorkspaceId, Guid SpaceId, Guid RequestId) : SpaceAccessIntent;

/// Answers the pending request `RequestId` for a Space with whether the
/// device owner authenticated. Only the request still pending may finish: a
/// lock cancels it, so a late answer never unlocks the Space for a newer one.
/// A refusal ends the request and grants nothing.
public sealed record FinishUnlockingSpace(Guid SpaceId, Guid RequestId, bool Authenticated) : SpaceAccessIntent;

/// Locks every Space again, cancelling a request waiting to unlock one. When
/// `SceneWentInactive`, the scene may only have made way for the system's own
/// authentication prompt, so while a request is waiting nothing locks.
public sealed record LockAllSpaces(bool SceneWentInactive) : SpaceAccessIntent;

/// Locks a Space again: every grant for it is revoked, and a request waiting
/// to unlock it is cancelled.
public sealed record LockSpace(Guid SpaceId) : SpaceAccessIntent;

#endregion

#region Rejections

/// Another request to unlock a Space is waiting on the device owner.
public sealed record AuthenticationBusy() : Rejection;

/// The request this answer finishes is no longer the one pending: a lock
/// cancelled it, it already finished, or it was for another Space.
public sealed record StaleUnlockRequest(Guid RequestId) : Rejection;

#endregion
