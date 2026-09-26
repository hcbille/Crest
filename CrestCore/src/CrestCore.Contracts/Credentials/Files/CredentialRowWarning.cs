namespace CrestCore.Contracts;

/// Row `RowNumber` of a password file, counting its header as row 1, imports
/// with `Caution`.
public sealed record CredentialRowWarning(int RowNumber, CredentialRowCaution Caution);
