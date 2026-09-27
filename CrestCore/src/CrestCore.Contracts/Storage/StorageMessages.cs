namespace CrestCore.Contracts;

#region Intents

/// Gives a session file that holds no session its first one: the session the
/// installed release kept in its defaults, carried once with its history and
/// sync journal, or when there is nothing to carry `Seed`, or without one the
/// session a first launch starts with (`FirstInstallSession`). An installed
/// session that does not decode stays where it is and the seed stands in; the
/// core then leaves the cloud-recovery marker beside the file, so the cloud
/// transport replaces the seed with a full pull instead of uploading it as a
/// deletion of every Space the cloud still holds. The file is written before
/// the intent returns. A core whose file already holds a session, or that
/// keeps nothing on disk, publishes nothing.
///
/// `Seed` is a session a platform builds, such as an isolated run's fixture:
/// its fields alone, as a platform sends any record the core resolves values
/// of, with each Space's history inside it.
///
/// It is the one message that carries a whole session with its history and
/// journal, so it may take as much as one stored session part. An installed
/// release kept each value in its defaults, which hold a few megabytes a value
/// in practice: a session core and a journal of up to about 4 MiB each and a
/// full history of about 2 MiB a Space.
[MessageLimit(64 * 1024 * 1024)]
public sealed record AdoptLegacySession(LegacySession Installed, SessionState? Seed) : Intent;

/// What an installed release kept in its defaults, exactly as the host read it:
/// the session without its history or images (`Core`), the whole-graph session
/// the releases before that split wrote (`WholeGraph`), each Space's history
/// beside `Core`, and the sync journal. The core decodes all of it. When `Core`
/// is present it is the installed session and `WholeGraph` is ignored.
public sealed record LegacySession(byte[]? Core, byte[]? WholeGraph, IReadOnlyList<LegacyHistory> History, byte[]? Journal);

/// One Space's history as an installed release kept it beside the session.
public sealed record LegacyHistory(Guid SpaceId, byte[] Entries);

#endregion

#region Queries

/// <summary>Which file revision the core has handed its session file and not yet
/// written, so a caller can wait until it is on disk. The stored session's edits
/// and this device's saved windows each take one.</summary>
public sealed record PendingSave : Query<PendingSaveRevision>;

/// <summary>The newest file revision not yet on disk, which a later <c>Saved</c>
/// names; null when everything accepted is saved or the core keeps nothing.</summary>
public sealed record PendingSaveRevision(long? Revision);

#endregion

#region Changes

/// Everything the core handed its session file up to file revision `Revision`
/// is on disk: the stored session's edits and this device's saved windows.
public sealed record Saved(long Revision) : Change;

/// The session file holds its first session. `Favicons` are the images the
/// adopted session carried inside its tabs, for the host's image store; the
/// core keeps none of them.
public sealed record SessionAdopted(IReadOnlyList<TabFavicon> Favicons) : Change;

/// The image a tab shows, as the platform stored it.
public sealed record TabFavicon(Guid TabId, byte[] Image);

/// A save the core started on its own failed. The accepted session stays in
/// memory, and the next save writes everything that is not yet on disk.
public sealed record StorageFailed(StorageFailure Reason) : Change;

#endregion

#region Rejections

/// The recovery checkpoint cannot be restored: there is none, it does not hold
/// a complete session and journal, or it could not be put in place. A restore
/// that stops after it began setting the file aside leaves the restore marker,
/// so the directory stays refused until a restore completes.
public sealed record RecoveryCheckpointUnusable(StorageFailure Reason) : Rejection;

/// A save the intent had to finish before returning failed. Nothing was
/// published, and the file is as it was.
public sealed record SaveFailed(StorageFailure Reason) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Crest couldn’t save this change. Try again.";

    #endregion
}

/// The stored session or its sync journal was written by a newer version of
/// the app, which this build must not overwrite.
public sealed record StorageFromNewerApp : Rejection;

/// A restore from the recovery checkpoint did not finish. The core refuses the
/// directory until the restore completes, so a partial restore can never
/// become a fresh session.
public sealed record StorageRestoreInterrupted : Rejection;

/// The stored session could not be opened. Nothing was written to it.
public sealed record StorageUnreadable(StorageFailure Reason) : Rejection;

#endregion

#region Models

/// Why the session's storage could not be read or written.
public enum StorageFailure {
    /// The disk has no room for the write.
    DiskFull,
    /// The file or its directory cannot be written.
    ReadOnly,
    /// Another connection held the file for longer than the core waits.
    Busy,
    /// The file is not a readable session: a damaged database, a missing part
    /// or a part that does not decode.
    Damaged,
    /// Any other failure to open, read or write the file.
    Unavailable
}

#endregion
