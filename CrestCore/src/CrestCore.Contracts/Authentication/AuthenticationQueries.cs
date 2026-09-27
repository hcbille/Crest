namespace CrestCore.Contracts;

/// The server a credential prompt names: its host, port and scheme. The host
/// may be empty.
public sealed record AuthenticationSource(string Host, int Port, string? Scheme) : Query<AuthenticationSourceLabel>;

/// The server as the prompt names it, or null when the challenge has no host
/// and the platform names Crest itself.
public sealed record AuthenticationSourceLabel(string? Label);

/// How Crest answers one HTTP authentication challenge. No username or
/// password crosses: a challenge is its method, whether a proxy asks, and how
/// many attempts the server has refused.
public sealed record ChallengeHandling(AuthenticationMethod Method, bool IsProxy, int PreviousFailureCount) : Query<ChallengeHandled>;

/// The challenge schemes Crest answers with its own credential prompt.
public enum AuthenticationMethod { HttpBasic, HttpDigest, Other }

/// How the challenge is answered.
public sealed record ChallengeHandled(AuthenticationHandling Handling);

/// How one authentication challenge is answered.
public enum AuthenticationHandling { PromptForCredentials, PerformDefaultHandling, Cancel }

/// Whether this build trusts a server certificate the system refused: only
/// the physical-validation fixture build does, and only for the certificate
/// whose SHA-256 fingerprint it was built with.
public sealed record FixtureServerTrust(string? BundleIdentifier, string? ExpectedCertificateSha256, string ActualCertificateSha256)
    : Query<FixtureServerTrusted>;

/// Whether the build trusts the certificate.
public sealed record FixtureServerTrusted(bool Trusted);
