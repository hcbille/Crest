namespace CrestCore.Contracts;

/// The Spaces the Crest browser-data file at `Path` holds, as an import brings
/// them, without importing anything: each Space with its tabs, folders,
/// splits, archive and history, every identity new. The platform holds any
/// access the file needs while the core reads it, and asks away from the main
/// thread.
///
/// Refused with `FileUnreadable` for a file that cannot be read,
/// `ArchiveTooLarge` for one past the limit, `NotAnArchive` for a file that is
/// not Crest browser data, `UnsupportedArchiveVersion` for one a newer Crest
/// wrote, and `ArchiveInvalid` for one holding anything Crest would not keep.
public sealed record ReadArchive(string Path) : Query<ImportedSpaces>;
