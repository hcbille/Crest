namespace CrestCore.Contracts;

/// Where a lift of `Selection` in a window's sidebar may drop, answered once as
/// the lift begins: the rule that refuses the lift, the lists and Spaces it may
/// reach, and whether it may join the cards on show. Each list or Space drop is
/// checked as the lift reaches it. A drop may still be refused when it lands,
/// since the session can change while the lift is held; its commit decides.
public sealed record DropTargets(Guid WorkspaceId, Guid WindowId, Guid SpaceId, TabSelection Selection) : Query<DropTargetList>;
