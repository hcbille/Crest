namespace CrestCore.Contracts;

/// Whether Crest takes the address.
public sealed record ExternalAddressVerdict(bool Accepted);

/// What the platform's URL parser reports about a candidate local document:
/// whether it is a `file:` URL, whether it names a user, whether its path is
/// non-empty, and its host (null or empty when it has none).
public sealed record LocalDocumentFacts(bool IsFile, bool HasUser, bool HasPath, string? Host);

/// Who owns the navigation.
public sealed record SchemeHandled(ExternalSchemeDisposition Disposition);
