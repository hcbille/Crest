namespace CrestCore.Contracts;

/// The server as the prompt names it, or null when the challenge has no host
/// and the platform names Crest itself.
public sealed record AuthenticationSourceLabel(string? Label);

/// The challenge schemes Crest answers with its own credential prompt.
public enum AuthenticationMethod { HttpBasic, HttpDigest, Other }

/// How the challenge is answered.
public sealed record ChallengeHandled(AuthenticationHandling Handling);

/// How one authentication challenge is answered.
public enum AuthenticationHandling { PromptForCredentials, PerformDefaultHandling, Cancel }
