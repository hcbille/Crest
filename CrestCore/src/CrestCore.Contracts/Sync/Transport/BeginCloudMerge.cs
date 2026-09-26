namespace CrestCore.Contracts;

/// The transport is about to merge downloaded records into the session. The
/// device store notes first that a full pull must recover them, since the
/// engine may save a cursor past them even when the merge never completes.
/// Answers `CloudMergeBegan` naming the merge for `FinishCloudMerge`.
public sealed record BeginCloudMerge : CloudTransportIntent;
