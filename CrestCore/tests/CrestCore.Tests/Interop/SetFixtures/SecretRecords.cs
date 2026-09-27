using CrestCore.Contracts;

namespace CrestCore.Tests.Secret;

/// A password.
[HoldsSecrets]
public sealed record Unlock(string Owner, string Password) : Intent;

/// Saved passwords in a list, beside a count of its own.
public sealed record Remember(IReadOnlyList<ExistingCredential> Credentials, int Hooks) : Intent;

/// A saved password, maybe.
public sealed record Recall(ExistingCredential? Credential) : Intent;

/// Nothing secret.
public sealed record Note(string Text) : Intent;
