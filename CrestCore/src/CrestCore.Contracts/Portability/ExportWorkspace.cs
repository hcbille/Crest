namespace CrestCore.Contracts;

/// The file `Format` writes of the workspace's Spaces, in their order, as the
/// session holds them now. Passwords, cookies, website storage, permissions,
/// downloads, favicons and extensions are never part of it.
///
/// Refused with `SpaceLocked` while any of its Spaces is locked, since the
/// file would carry that Space's tabs and history, and `ArchiveTooLarge` or
/// `BookmarksTooLarge` when the file would be larger than an import reads.
public sealed record ExportWorkspace(Guid WorkspaceId, ExportFormat Format) : Query<ExportedDocument>;
