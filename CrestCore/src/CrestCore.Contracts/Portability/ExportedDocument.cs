namespace CrestCore.Contracts;

/// A file's contents, to save as `Format` names.
public sealed record ExportedDocument(byte[] Contents, ExportFormat Format);
