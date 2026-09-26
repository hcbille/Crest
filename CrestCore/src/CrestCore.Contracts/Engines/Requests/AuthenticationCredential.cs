namespace CrestCore.Contracts;

/// A user name and password for an HTTP challenge.
public sealed record AuthenticationCredential(string Username, string Password);
