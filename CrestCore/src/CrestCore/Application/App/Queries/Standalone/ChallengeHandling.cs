using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// How Crest answers one HTTP authentication challenge. No username or
/// password crosses: a challenge is its method, whether a proxy asks, and how
/// many attempts the server has refused.
public sealed record ChallengeHandling(AuthenticationMethod Method, bool IsProxy, int PreviousFailureCount)
    : StandaloneQuery<ChallengeHandled> {
    #region Actions - Answering

    internal override ChallengeHandled Answer(StandaloneContext context) =>
        new(AuthenticationPolicy.Handling(Method, IsProxy, PreviousFailureCount));

    #endregion
}
