namespace CrestCore.Contracts;

/// A verified connection's certificates as DER, the leaf first; none when the
/// page was not loaded over a verified TLS connection.
public sealed record CertificateChain(IReadOnlyList<byte[]> Certificates);
