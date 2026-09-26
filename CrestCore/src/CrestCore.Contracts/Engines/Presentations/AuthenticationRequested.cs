namespace CrestCore.Contracts;

/// A server the page loads from asked for a user name and password: `Host` and
/// `Port` of `Url`, in `Realm`, with `Scheme`, after `PreviousFailures` wrong
/// answers. The load waits for `AnswerAuthentication`. TRANSITIONAL until page
/// dialogs move to the core (WP C (e)).
public sealed record AuthenticationRequested(Guid PageId, Guid ChallengeId, string Url, string Host, int Port,
    string? Realm, AuthenticationScheme Scheme, bool IsProxy, int PreviousFailures) : EnginePresentation;
