namespace CrestCore.Contracts;

/// Answers a server's request with `Credential`, or cancels it with none.
public sealed record SettleAuthentication(Guid PromptId, AuthenticationCredential? Credential) : EngineCommand;
