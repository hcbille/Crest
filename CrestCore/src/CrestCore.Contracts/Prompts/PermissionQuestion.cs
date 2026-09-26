namespace CrestCore.Contracts;

/// A document in a page asked for `Permission`, from `Origin` inside
/// `TopLevelOrigin`.
public sealed record PermissionQuestion(SitePermission Permission, SiteOrigin Origin, SiteOrigin TopLevelOrigin);
