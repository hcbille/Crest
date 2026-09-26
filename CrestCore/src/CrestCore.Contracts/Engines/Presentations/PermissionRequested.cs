namespace CrestCore.Contracts;

/// A document in the page asked for `Permission`, from `Origin` inside
/// `TopLevelOrigin`. The request waits for `AnswerPermission`. TRANSITIONAL
/// until permission prompts move to the core (WP C (f)).
public sealed record PermissionRequested(Guid PageId, Guid RequestId, SitePermission Permission, string Origin,
    string TopLevelOrigin) : EnginePresentation;
