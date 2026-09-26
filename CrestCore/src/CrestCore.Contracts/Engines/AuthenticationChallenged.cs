namespace CrestCore.Contracts;

/// A server a page loads from asked for a user name and password; the load
/// waits for the core's `SettleAuthentication`.
public sealed record AuthenticationChallenged(Guid PromptId, Guid PageId, AuthenticationQuestion Question) : EngineEvent;
