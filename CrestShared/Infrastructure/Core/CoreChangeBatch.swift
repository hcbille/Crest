import Foundation

/// What one batch of the core's changes holds for `CrestCore`'s followers,
/// gathered while the read model applies it, so each follower hears its part
/// once the whole batch is applied: the records pages made, site permission
/// and download changes, pages unloaded, put away, moved to another engine or
/// adopted, and the close preparations and data deletions that ended. A save
/// that failed and a journal the core staged are handed on at once. It
/// observes only these changes.
@MainActor
final class CoreChangeBatch: ChangeObserving {
    // MARK: - Variables

    private unowned let core: CrestCore
    private(set) var pageRecords = Engines.PageRecords()
    private(set) var permissionChanges: [SitePermissionsChanged] = []
    private(set) var downloadChanges: [DownloadState] = []
    private(set) var unloadedPages: [PageUnloaded] = []
    private(set) var putAwayPages: [TabPagePutAway] = []
    private(set) var rehostedPages: [PageRehosted] = []
    private(set) var adoptedPages: [OfferedPageAdopted] = []
    private(set) var closesReady: [CloseReady] = []
    private(set) var dataDeleted: [DataDeleted] = []

    // MARK: - Initializers

    init(core: CrestCore) {
        self.core = core
    }

    // MARK: - Actions - Changes

    func handle(_ change: StorageFailed) {
        core.storageFailed(change.reason)
    }

    func handle(_ change: SyncJournalChanged) {
        core.syncJournalChangeHandler?()
    }

    func handle(_ change: NavigationRecorded) {
        pageRecords.navigations.append(change)
    }

    /// Only an icon a page reported is one of its records.
    func handle(_ change: TabFaviconAssigned) {
        if change.pageID != nil { pageRecords.icons.append(change) }
    }

    func handle(_ change: SitePermissionsChanged) {
        permissionChanges.append(change)
    }

    func handle(_ change: DownloadUpdated) {
        downloadChanges.append(change.download)
    }

    func handle(_ change: PageUnloaded) {
        unloadedPages.append(change)
    }

    func handle(_ change: TabPagePutAway) {
        putAwayPages.append(change)
    }

    func handle(_ change: PageRehosted) {
        rehostedPages.append(change)
    }

    func handle(_ change: OfferedPageAdopted) {
        adoptedPages.append(change)
    }

    func handle(_ change: CloseReady) {
        closesReady.append(change)
    }

    func handle(_ change: DataDeleted) {
        dataDeleted.append(change)
    }
}
