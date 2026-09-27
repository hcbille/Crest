namespace CrestCore.Contracts;

/// The file `Format` writes of the workspace's Spaces, in their order, as the
/// session holds them now. Passwords, cookies, website storage, permissions,
/// downloads, favicons and extensions are never part of it.
///
/// Refused with `SpaceLocked` while any of its Spaces is locked, since the
/// file would carry that Space's tabs and history, and `ArchiveTooLarge` or
/// `BookmarksTooLarge` when the file would be larger than an import reads.
public sealed record ExportWorkspace(Guid WorkspaceId, ExportFormat Format) : Query<ExportedDocument>;

/// A file's contents, to save as `Format` names.
public sealed record ExportedDocument(byte[] Contents, ExportFormat Format);

/// The profiles and password stores `Source` keeps in `Folder`, the folder
/// where the browser keeps its data. The platform holds any access the folder
/// needs while the core looks; a folder that is missing or unreadable holds
/// none.
public sealed record FindImportData(ImportSource Source, string Folder) : Query<ImportData>;

/// What a browser keeps in its data folder: each profile with the files an
/// import reads, and each store of saved passwords, in the order a person
/// meets them there.
public sealed record ImportData(IReadOnlyList<ImportProfile> Profiles, IReadOnlyList<ImportPasswordStore> PasswordStores);

/// A profile's store of saved passwords: `Id`, the name the browser keeps the
/// profile under, the `ProfileName` the person gave it, and the store's path.
public sealed record ImportPasswordStore(string Id, string ProfileName, string Path);

/// One profile of a browser: `Id`, the name the browser keeps it under, the
/// `Name` the person gave it, and the paths of its bookmarks and of its latest
/// session, where it keeps either. A profile keeps at least one.
public sealed record ImportProfile(string Id, string Name, string? BookmarksPath, string? SessionPath);

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

/// The Spaces an import would bring, in order, each with new identities, the
/// way `ImportSpaces` takes them.
public sealed record ImportedSpaces(IReadOnlyList<SpaceState> Spaces);

/// The Spaces an import of `Profiles` from `Source` brings, read from the
/// files each profile names, without importing anything. A source that names
/// its own Spaces brings them as named there; any other brings one Space for
/// each profile, holding its bookmarks as saved tabs and its open tabs, and
/// named after it. A file that cannot be read is skipped while another brings
/// a Space.
///
/// The platform holds any access the files need while the core reads them,
/// and asks away from the main thread: the core answers without waiting for
/// any other work. Refused with the rejection of the last file that could not
/// be read, such as `SessionUnrecognized` or `BookmarksOverLimits`, when
/// nothing could be brought, `SessionHasNoTabs` when no profile names a file,
/// and `SessionOverLimits` when the source brings more Spaces than a
/// workspace keeps.
public sealed record ReadImport(ImportSource Source, IReadOnlyList<ImportProfile> Profiles) : Query<ImportedSpaces>;

#region Models

/// How a review heads each Space an import brings: with the Space's own name
/// and look, or with a plain section label, for a browser whose Spaces are
/// sections of one sidebar.
public enum ImportSpaceHeaderStyle {
    Identity,
    SectionLabel
}

/// `Source`'s `SpaceName` and `NumberedSpaceName` in the person's language, as
/// the platform resolved them, so a Space an import names is stored as the
/// person reads it. `NumberedSpaceName` keeps its `%lld`.
public sealed record ImportSpaceNames(ImportSource Source, string SpaceName, string NumberedSpaceName);

#endregion
