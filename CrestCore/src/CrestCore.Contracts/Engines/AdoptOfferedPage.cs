namespace CrestCore.Contracts;

/// Makes the page the engine offered as `OfferId` the page `PageId` names,
/// which the core opened for a tab, in the profile `ProfileId` names and the
/// window `WindowId` names. A private page keeps nothing once it closes. The
/// binding answers with `PageCreated`, or `PageCreationFailed` when the offer
/// is gone.
public sealed record AdoptOfferedPage(Guid PageId, Guid OfferId, Guid ProfileId, bool IsPrivate, Guid WindowId)
    : EngineCommand;
