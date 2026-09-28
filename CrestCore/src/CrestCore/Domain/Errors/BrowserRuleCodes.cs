namespace CrestCore.Domain;

/// Stable browser rule error code identifiers exposed to native callers.
public static class BrowserRuleCodes {
    #region Variables

    public const string AccessAlreadyAttached = "access_already_attached";
    public const string BorrowedProfileRequiresOwner = "borrowed_profile_requires_owner";
    public const string DuplicateSyncRecord = "duplicate_sync_record";
    public const string InvalidAddress = "invalid_address";
    public const string InvalidDeletionIntent = "invalid_deletion_intent";
    public const string InvalidFolderTree = "invalid_folder_tree";
    public const string InvalidHistoryRange = "invalid_history_range";
    public const string InvalidHistoryVisit = "invalid_history_visit";
    public const string InvalidIdentity = "invalid_identity";
    public const string InvalidNativeKind = "invalid_native_kind";
    public const string InvalidRecordDate = "invalid_record_date";
    public const string InvalidRecoveryIdentity = "invalid_recovery_identity";
    public const string InvalidRetentionInterval = "invalid_retention_interval";
    public const string InvalidSavedDate = "invalid_saved_date";
    public const string InvalidSavedIdentity = "invalid_saved_identity";
    public const string InvalidSavedState = "invalid_saved_state";
    public const string InvalidSavedUrl = "invalid_saved_url";
    public const string InvalidSessionTransaction = "invalid_session_transaction";
    public const string InvalidShortcut = "invalid_shortcut";
    public const string InvalidSplit = "invalid_split";
    public const string InvalidSyncDate = "invalid_sync_date";
    public const string InvalidSyncDeletion = "invalid_sync_deletion";
    public const string InvalidSyncKind = "invalid_sync_kind";
    public const string InvalidSyncPending = "invalid_sync_pending";
    public const string InvalidSyncPlacement = "invalid_sync_placement";
    public const string InvalidSyncRecord = "invalid_sync_record";
    public const string InvalidSyncSessionOwner = "invalid_sync_session_owner";
    public const string InvalidSyncTransaction = "invalid_sync_transaction";
    public const string InvalidTabContent = "invalid_tab_content";
    public const string InvalidTerminationCount = "invalid_termination_count";
    public const string NotBorrowedWorkspace = "not_borrowed_workspace";
    public const string ProfileLeaseRevoked = "profile_lease_revoked";
    public const string SessionReleased = "session_released";
    public const string SessionTransactionInProgress = "session_transaction_in_progress";
    public const string StaleBorrowedSource = "stale_borrowed_source";
    public const string SyncClockExhausted = "sync_clock_exhausted";
    public const string SyncIdentityMismatch = "sync_identity_mismatch";
    public const string SyncRecordLimit = "sync_record_limit";
    public const string SyncSizeLimit = "sync_size_limit";
    public const string SyncTransactionNotSealed = "sync_transaction_not_sealed";
    public const string UnknownCurrentTab = "unknown_current_tab";
    public const string UnknownFolder = "unknown_folder";
    public const string UnsupportedUrl = "unsupported_url";
    public const string VersionMismatch = "version_mismatch";

    #endregion
}
