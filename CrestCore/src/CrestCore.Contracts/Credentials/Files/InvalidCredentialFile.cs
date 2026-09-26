namespace CrestCore.Contracts;

/// A password file cannot be imported, for the reason `Flaw` names.
public sealed record InvalidCredentialFile(CredentialFileFlaw Flaw) : Rejection;
