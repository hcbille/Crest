namespace CrestCore.Contracts;

/// Whether Crest opens an address as a local document, from the facts the
/// platform's own parser reported. Only document-open routes ask.
public sealed record ExternalLocalDocument(LocalDocumentFacts Facts) : Query<ExternalAddressVerdict>;

/// Whether Crest takes the address.
public sealed record ExternalAddressVerdict(bool Accepted);

/// What the platform's URL parser reports about a candidate local document:
/// whether it is a `file:` URL, whether it names a user, whether its path is
/// non-empty, and its host (null or empty when it has none).
public sealed record LocalDocumentFacts(bool IsFile, bool HasUser, bool HasPath, string? Host);

/// Whether another app, a drop, a Peek, a popup or a menu may hand Crest an
/// address as a web link: HTTP or HTTPS with a host. The address arrives as
/// the scheme and host the platform's own parser reported.
public sealed record ExternalWebLink(string? Scheme, string? Host) : Query<ExternalAddressVerdict>;

/// Which engine, if any, owns a navigation once its scheme is known. Only a
/// load Crest itself started may keep `file:`.
public sealed record SchemeHandling(string? Scheme, bool AppInitiated) : Query<SchemeHandled>;

/// Who owns the navigation.
public sealed record SchemeHandled(ExternalSchemeDisposition Disposition);
