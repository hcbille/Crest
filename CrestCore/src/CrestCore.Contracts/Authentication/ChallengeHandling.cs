namespace CrestCore.Contracts;

/// How Crest answers one HTTP authentication challenge. No username or
/// password crosses: a challenge is its method, whether a proxy asks, and how
/// many attempts the server has refused.
public sealed record ChallengeHandling(AuthenticationMethod Method, bool IsProxy, int PreviousFailureCount) : Query<ChallengeHandled>;
