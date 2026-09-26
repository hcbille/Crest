namespace CrestCore.Contracts;

/// A merge of downloaded records began as `MergeId`.
public sealed record CloudMergeBegan(long MergeId) : Change;
