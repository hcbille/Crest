namespace CrestCore.Contracts;

/// Starts importing the review, before the platform reads the passwords it
/// brings and sends `ImportReviewedSpaces`.
///
/// Refused with `NoIncludedSpaces` when the review brings no Space.
public sealed record BeginImportCommit() : SetupFlowIntent;
