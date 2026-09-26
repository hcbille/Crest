import Foundation

/// WebKit's binding, on the Mac and on iPhone and iPad. For now the page's
/// owner builds the WebKit page with the factory it already had, because that
/// factory carries the owner's configuration, content rules and website data
/// stores; the binding runs it when the core asks WebKit to create the page,
/// and loads an address through the owner's own load, which prepares the
/// page for it. The owner tears the web view down when it releases the page,
/// so closing only tells the core the page is gone. TRANSITIONAL until WP C
/// (j1): a page the core unloads hands it no restore state; its owner archives
/// WebKit's state from the live web view instead.
@MainActor
final class WebKitEngineBinding: EngineBinding {
    // MARK: - Variables

    let integration = BrowserEngineRegistration.webKit
    private weak var engines: Engines?

    // MARK: - Actions - Binding

    func attach(to engines: Engines) {
        self.engines = engines
    }

    func run(_ command: EngineCommand) {
        guard let engines else { return }
        switch command {
        case .createPage(let creation):
            guard let request = engines.request(creation.pageID), let built = request.makeWebKitPage(request.page)
            else {
                engines.report(PageCreationFailed(pageID: creation.pageID), from: self)
                return
            }
            request.built = built
            engines.report(PageCreated(pageID: creation.pageID), from: self)
        case .loadPage(let loading):
            guard let url = URL(string: loading.url) else { return }
            (engines.page(loading.pageID) ?? engines.request(loading.pageID)?.page)?.appLoad?(url)
        case .closePage(let closing):
            engines.report(PageClosed(pageID: closing.pageID, restoreState: nil), from: self)
        case .checkBeforeUnload(let check):
            // WebKit runs a page's beforeunload handlers for an embedder close
            // only where its page can ask; any other page may go.
            guard let prepare = engines.page(check.pageID)?.appPrepareToClose else {
                engines.report(BeforeUnloadAnswered(pageID: check.pageID, proceeds: true), from: self)
                return
            }
            prepare { [weak self] proceeds in
                guard let self else { return }
                self.engines?.report(BeforeUnloadAnswered(pageID: check.pageID, proceeds: proceeds), from: self)
            }
        case .recoverPage, .settleScriptDialog, .settleAuthentication, .settlePermission, .settleExtensionInstall,
            .settleDownloadDestination, .cancelEngineDownload, .removeEngineDownload, .approveEngineDownload:
            // WebKit recovers its own pages, answers its own prompts and runs
            // its own downloads until its binding reports them to the core
            // (WP C (j1)), so the core never asks it to.
            break
        }
    }
}
