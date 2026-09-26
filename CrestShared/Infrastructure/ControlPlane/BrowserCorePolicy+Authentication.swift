import Foundation

/// HTTP authentication rules answered by the portable core. No username or
/// password crosses: a challenge is its method, proxy flag and failure count.
extension BrowserCorePolicy {
    // MARK: - Actions - Authentication

    /// How one challenge is answered. An unavailable core cancels the
    /// challenge rather than prompting or handing over stored credentials.
    static func authenticationHandling(for challenge: BrowserAuthenticationChallenge) -> AuthenticationHandling {
        authenticationHandling(
            method: challenge.authenticationMethod, isProxy: challenge.isProxy,
            previousFailureCount: challenge.previousFailureCount)
    }

    static func authenticationHandling(
        method: AuthenticationMethod, isProxy: Bool,
        previousFailureCount: Int
    ) -> AuthenticationHandling {
        let question = ChallengeHandling(method: method, isProxy: isProxy, previousFailureCount: previousFailureCount)
        return (try? CrestCore.answer(question))?.handling ?? .cancel
    }

    /// The server as the credential prompt names it. The core owns the
    /// formatting; without its answer the prompt uses the generic label. A
    /// prompt never appears without the core in practice, because
    /// `authenticationHandling` cancels the challenge when it cannot answer.
    static func authenticationSourceLabel(host: String, port: Int, scheme: String?, emptyHostLabel: String) -> String {
        let question = AuthenticationSource(host: host, port: port, scheme: nonEmpty(scheme))
        return (try? CrestCore.answer(question))?.label ?? emptyHostLabel
    }

    /// Whether the physical-validation fixture build trusts this server
    /// certificate. An unavailable core trusts nothing.
    static func trustsPhysicalValidationServer(
        bundleIdentifier: String?, expectedCertificateSHA256: String?,
        actualCertificateSHA256: String
    ) -> Bool {
        let question = FixtureServerTrust(
            bundleIdentifier: nonEmpty(bundleIdentifier),
            expectedCertificateSha256: nonEmpty(expectedCertificateSHA256),
            actualCertificateSha256: actualCertificateSHA256)
        return (try? CrestCore.answer(question))?.trusted ?? false
    }
}
