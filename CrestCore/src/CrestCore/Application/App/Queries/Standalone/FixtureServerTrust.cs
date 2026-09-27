using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// Whether this build trusts a server certificate the system refused: only
/// the physical-validation fixture build does, and only for the certificate
/// whose SHA-256 fingerprint it was built with.
public sealed record FixtureServerTrust(string? BundleIdentifier, string? ExpectedCertificateSha256, string ActualCertificateSha256)
    : StandaloneQuery<FixtureServerTrusted> {
    #region Actions - Answering

    internal override FixtureServerTrusted Answer(StandaloneContext context) =>
        new(AuthenticationPolicy.TrustsPhysicalValidationServer(BundleIdentifier, ExpectedCertificateSha256, ActualCertificateSha256));

    #endregion
}
