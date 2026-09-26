namespace CrestCore.Contracts;

/// The first load of the page `PageId` names, when it loads `Url`, runs the
/// link the engine of `SourcePageId` staged as `StagedLinkId`. Refused with
/// `StagedLinkElsewhere` when the page is on another engine or profile than
/// the page the link was followed in, or its engine already holds its page.
public sealed record StageLink(Guid PageId, Guid SourcePageId, Guid StagedLinkId, string Url) : PageIntent;
