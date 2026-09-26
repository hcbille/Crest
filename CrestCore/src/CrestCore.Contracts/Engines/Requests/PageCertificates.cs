namespace CrestCore.Contracts;

/// The certificates the page's visible entry was verified with.
public sealed record PageCertificates(Guid PageId) : PageRequest<CertificateChain>;
