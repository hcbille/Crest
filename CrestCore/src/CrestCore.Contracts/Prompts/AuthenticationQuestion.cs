namespace CrestCore.Contracts;

/// A server a page loads from asked for a user name and password: `Host` and
/// `Port` of `Url`, in `Realm`, with `Scheme`, after `PreviousFailures` wrong
/// answers.
public sealed record AuthenticationQuestion(string Url, string Host, int Port, string? Realm, AuthenticationScheme Scheme,
    bool IsProxy, int PreviousFailures);
