import Foundation

/// The window this pool hosts pages for, as its callers name it: what the
/// window shows now. TRANSITIONAL until the one WebKit binding (WP C j1/j2)
/// hosts pages from the core's read model: the pool still reads the window's
/// session copy through its store here, so no feature code has to.
extension BrowserPagePool {
    // MARK: - Variables

    /// What the pool's runtime state follows in the window's workspace: tab
    /// icons, content blocking and credential access, compared between
    /// changes so each is reconciled only when it moved.
    var runtimeProjection: BrowserRuntimeSessionProjection {
        BrowserRuntimeSessionProjection(session: browser.session)
    }

    // MARK: - Actions - Window

    /// Presents what the window shows.
    func select(at time: Date = .now) {
        select(session: browser.presented, at: time)
    }

    /// Releases the pages of tabs the window's workspace no longer holds and
    /// keeps the rest current.
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

    /// Whether the pool presents what the window shows.
    func isPresentingSelection() -> Bool {
        isPresentingSelection(in: browser.presented)
    }

    func reloadOrStop() {
        reloadOrStop(in: browser.presented)
    }

    func forceReload() {
        forceReload(in: browser.presented)
    }

    func reloadFromOrigin() {
        reloadFromOrigin(in: browser.presented)
    }

    /// Takes a locked Space's pages off screen and files their state, by the
    /// Space of the read model.
    func relockProtectedSpace(_ space: SpaceModel) {
        guard let copy = browser.session.space(id: space.id) else { return }
        relockProtectedSpace(copy)
    }
}
