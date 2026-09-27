#if DEBUG
    import Foundation

    extension CrestCore {
        /// A memory-only core that hosts pages the way the app composes one, for
        /// tests: WebKit is registered as its default engine, erasing its
        /// profiles' stores with `profileStores`.
        static func hostingPages(
            profileStores: any BrowserEngineProfileRemoving = WebKitBrowserWebsiteDataStoreRemover()
        ) -> CrestCore {
            let core = CrestCore()
            core.engines.register(WebKitEngineBinding(profileStores: profileStores), isDefault: true)
            return core
        }
    }

    extension BrowserStore {
        /// A window that hosts pages the way the app composes one, for tests: a
        /// family the core opens from `seed`, whose tabs wear `images`, on a
        /// core that hosts pages, and a window open over it that shows
        /// `spaceID` and `tabs` as `init(seed:images:showing:tabs:)` does. A
        /// page pool or store over this window opens every page through that
        /// core, so a page can only live in one of the session's Spaces. Pass
        /// `core` to put another workspace on a core that already hosts one, as
        /// private and temporary windows share the app's core.
        static func hostingPages(
            _ seed: SessionState.Seed = .preview,
            images: [UUID: Data] = [:],
            showing spaceID: SpaceID? = nil,
            tabs: [SpaceID: TabID] = [:],
            browsingMode: BrowserBrowsingMode = .standard,
            core: CrestCore = .hostingPages()
        ) -> BrowserStore {
            BrowserStore(
                seed: seed, images: images, showing: spaceID, tabs: tabs, browsingMode: browsingMode, core: core)
        }

        /// TRANSITIONAL until the tests that still build the session copy's
        /// values seed with `SessionState.Seed`: the window above over
        /// `session`, whose tabs wear the images it carries.
        static func hostingPages(
            _ session: BrowserSession,
            showing spaceID: SpaceID? = nil,
            tabs: [SpaceID: TabID] = [:],
            browsingMode: BrowserBrowsingMode = .standard,
            core: CrestCore = .hostingPages()
        ) -> BrowserStore {
            BrowserStore(session: session, showing: spaceID, tabs: tabs, browsingMode: browsingMode, core: core)
        }

        /// Tab `tabID` of Space `spaceID` as its page takes it, for a test that
        /// builds a page itself.
        func pageTab(_ tabID: TabID, in spaceID: SpaceID) -> BrowserPageTab {
            guard let tab = spaceModel(spaceID)?.tabs.model(tabID) else {
                preconditionFailure("A test built a page for a tab its window does not hold.")
            }
            return BrowserPageTab(tab, images: core.state.favicons)
        }

        /// Space `spaceID` of this window's workspace, for a test that builds a
        /// page itself.
        func hostedSpace(_ spaceID: SpaceID) -> SpaceModel {
            guard let space = spaceModel(spaceID) else {
                preconditionFailure("A test built a page for a Space its window does not hold.")
            }
            return space
        }

        /// Opens a page through the core for `tabID` in `spaceID`, and answers
        /// it with the page WebKit built from `webKit`, for a test that hosts
        /// the page itself. Nil when a rule refuses it.
        func openWebKitPage(
            in spaceID: SpaceID, for tabID: TabID?, webKit: WebKitPageInputs = WebKitPageInputs()
        ) -> (core: CorePage, webKit: WebKitEnginePage)? {
            guard let opened = openPage(in: spaceID, for: tabID, webKit: webKit) else { return nil }
            guard let page = opened.built as? WebKitEnginePage else {
                preconditionFailure("A test opened a page on an engine other than WebKit.")
            }
            return (opened.page, page)
        }
    }
#endif
