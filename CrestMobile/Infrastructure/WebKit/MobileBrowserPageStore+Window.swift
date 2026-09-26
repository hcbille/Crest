import Foundation

/// The scene this store hosts pages for, as its callers name it: what the
/// scene shows now. TRANSITIONAL until the one WebKit binding (WP C j1/j2)
/// hosts pages from the core's read model: the store still reads the scene's
/// session copy through its store here, so no feature code has to.
extension MobileBrowserPageStore {
    // MARK: - Variables

    /// What the pool's runtime state follows in the window's workspace: tab
    /// icons, content blocking and credential access, compared between
    /// changes so each is reconciled only when it moved.
    var runtimeProjection: BrowserRuntimeSessionProjection {
        BrowserRuntimeSessionProjection(session: browser.session)
    }

    /// Which tab of the workspace belongs to which Space and profile, which
    /// page residency follows.
    var tabRuntimeAssignments: Set<BrowserTabRuntimeAssignment> {
        browser.session.tabRuntimeAssignments
    }

    // MARK: - Actions - Window

    /// Presents what the scene shows.
    func select(at time: Date = .now) {
        select(session: browser.presented, at: time)
    }

    func reconcile() {
        reconcile(session: browser.session)
    }

    func reconcileTabIcons() {
        reconcileTabIcons(in: browser.session)
    }

    func reconcileCredentialAccess() {
        reconcileCredentialAccess(in: browser.session)
    }

    func reconcileContentBlocking() async {
        await reconcileContentBlocking(in: browser.session)
    }

    func reloadContentBlocking() async {
        await reloadContentBlocking(in: browser.session)
    }

    /// Loads what the person typed in the page the scene shows, preparing it
    /// first.
    @discardableResult
    func selectAndNavigate(to input: String) -> Bool {
        selectAndNavigate(to: input, in: browser.presented)
    }

    /// Builds the page a split card of the scene's shown Space is about to show.
    @discardableResult
    func prepareResidentPage(for tabID: TabID) -> MobileBrowserPage? {
        prepareResidentPage(for: tabID, in: browser.presented)
    }

    /// Takes a locked Space's pages off screen, by the Space of the read model.
    func relockProtectedSpace(_ space: SpaceModel) {
        guard let copy = browser.session.space(id: space.id) else { return }
        relockProtectedSpace(copy)
    }
}
