struct BrowserSiteControlConfiguration {
    let page: BrowserPage
    /// The page's Space for the engine's extension controls. TRANSITIONAL until
    /// Lane 2 moves them to the read model.
    let space: BrowserSpaceIdentity
    let selectedTabID: TabID?
    let permissionCenter: BrowserSitePermissionCenter
    let presentationChanged: (Bool) -> Void
    let contextMenuPresentationChanged: (Bool) -> Void
}
