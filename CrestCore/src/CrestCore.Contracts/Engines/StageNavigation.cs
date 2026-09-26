namespace CrestCore.Contracts;

/// The first load of the page `PageId` names, when it loads `Url`, runs the
/// link its engine staged as `StagedLinkId`, keeping the referrer, initiator
/// and security the link had where it was followed. The binding reports
/// `StagedLinkUnavailable` when the link no longer applies.
public sealed record StageNavigation(Guid PageId, Guid StagedLinkId, string Url) : EngineCommand;
