namespace CrestCore.Contracts;

/// The credential that answers the challenge `AuthenticationRequested`
/// presented, or none to cancel it. TRANSITIONAL until page dialogs move to
/// the core (WP C (e)).
public sealed record AnswerAuthentication(Guid PageId, Guid ChallengeId, AuthenticationCredential? Credential)
    : PageRequest<bool>;
