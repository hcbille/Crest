namespace CrestCore.Contracts;

/// The review is imported, with `PasswordCount` of its passwords. Setup goes
/// on to the next chosen browser; after the last, to setting up Spaces by hand
/// when it walks the person through Crest, or else to what it did.
public sealed record FinishImportCommit(int PasswordCount) : SetupFlowIntent;
