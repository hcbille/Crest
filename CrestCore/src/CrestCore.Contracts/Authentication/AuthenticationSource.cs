namespace CrestCore.Contracts;

/// The server a credential prompt names: its host, port and scheme. The host
/// may be empty.
public sealed record AuthenticationSource(string Host, int Port, string? Scheme) : Query<AuthenticationSourceLabel>;
