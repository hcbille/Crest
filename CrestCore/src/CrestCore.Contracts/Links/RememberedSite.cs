namespace CrestCore.Contracts;

/// The Space a Quick Window last opened a site in, which the next external
/// link to that site opens in when the preferences remember Spaces by site.
/// `Site` is the lowercased host without a leading `www.`.
public sealed record RememberedSite(string Site, Guid SpaceId);
