namespace CrestCore.Contracts;

/// Whether the origin is secure enough for the capability.
public sealed record SecureOriginVerdict(bool Allowed);
