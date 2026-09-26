namespace CrestCore.Contracts;

/// Whether a site may use a capability that needs a secure origin, such as
/// location or hosted notifications, at all.
public sealed record SecureOriginCheck(SiteOrigin Origin) : Query<SecureOriginVerdict>;
