namespace CrestCore.Contracts;

/// Row `RowNumber` of a password file, counting its header as row 1, is left
/// out for the reason `Flaw` names.
public sealed record CredentialRowRejection(int RowNumber, CredentialRowFlaw Flaw);
