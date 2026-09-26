namespace CrestCore.Contracts;

/// A server's request for a user name and password waits on the person.
public sealed record AuthenticationAsked(Guid PromptId, Guid PageId, AuthenticationQuestion Question) : Change;
