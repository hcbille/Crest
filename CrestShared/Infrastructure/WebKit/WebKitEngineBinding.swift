import Foundation
import WebKit

/// WebKit's binding, on the Mac and on iPhone and iPad. It builds each page
/// the core asks WebKit to create: the page's configuration for its profile,
/// with the platform's own settings, and the platform's web view, which the
/// page's owner then hosts. It loads an address through the owner's own load,
/// which prepares the page for it. The owner tears the web view down when it
/// releases the page, so closing only tells the core the page is gone.
/// TRANSITIONAL until WP C (j1): a page the core unloads hands it no restore
/// state; its owner archives WebKit's state from the live web view instead.
@MainActor
final class WebKitEngineBinding: EngineBinding {
    // MARK: - Types

    private struct WeakPage {
        weak var value: WebKitEnginePage?
    }

    // MARK: - Variables

    let integration = BrowserEngineRegistration.webKit
    private weak var engines: Engines?
    /// The pages this binding built, while their owners keep them.
    private var pages: [UUID: WeakPage] = [:]

    // MARK: - Actions - Binding

    func attach(to engines: Engines) {
        self.engines = engines
    }

    func run(_ command: EngineCommand) {
        guard let engines else { return }
        switch command {
        case .createPage(let creation):
            guard let request = engines.request(creation.pageID) else {
                engines.report(PageCreationFailed(pageID: creation.pageID), from: self)
                return
            }
            let page = build(creation, from: request.webKit)
            pages = pages.filter { $0.value.value != nil }
            pages[creation.pageID] = WeakPage(value: page)
            request.built = page
            engines.report(PageCreated(pageID: creation.pageID), from: self)
        case .loadPage(let loading):
            guard let url = URL(string: loading.url) else { return }
            (engines.page(loading.pageID) ?? engines.request(loading.pageID)?.page)?.appLoad?(url)
        case .closePage(let closing):
            pages[closing.pageID] = nil
            engines.report(PageClosed(pageID: closing.pageID, restoreState: nil), from: self)
        case .checkBeforeUnload(let check):
            prepareToClose(check.pageID)
        case .recoverPage(let recovery):
            // WebKit starts a new web content process for the page's current
            // history entry.
            pages[recovery.pageID]?.value?.webView.reload()
        case .settleScriptDialog, .settleAuthentication, .settlePermission, .settleExtensionInstall,
            .settleDownloadDestination, .cancelEngineDownload, .removeEngineDownload, .approveEngineDownload:
            // WebKit answers its own prompts and runs its own downloads until
            // its binding reports them to the core (WP C (j1)), so the core
            // never asks it to.
            break
        }
    }

    // MARK: - Actions - Pages

    /// The page for `creation`, with the configuration `inputs` hands over, or
    /// one assembled for the page's profile with the platform's own settings.
    private func build(_ creation: CreatePage, from inputs: WebKitPageInputs) -> WebKitEnginePage {
        let configuration =
            inputs.configuration
            ?? BrowserPageConfiguration.make(
                for: BrowsingProfile(id: creation.profileID),
                websiteDataStore: inputs.websiteDataStore,
                contentRuleLists: inputs.contentRuleLists,
                preferredContentMode: BrowserPlatformWebKit.preferredContentMode,
                decorate: BrowserPlatformWebKit.decorate)
        return WebKitEnginePage(
            id: creation.pageID,
            webView: BrowserPlatformWebKit.makeWebView(configuration: configuration),
            contentRuleLists: inputs.contentRuleLists,
            ownsUserContentController: !inputs.sharesUserContentController)
    }

    /// Asks the page's beforeunload handlers whether it may close, where
    /// WebKit runs them for an embedder close; any other page may go.
    private func prepareToClose(_ pageID: UUID) {
        #if os(macOS)
            if let page = pages[pageID]?.value {
                page.engine.prepareToClose { [weak self] proceeds in
                    guard let self else { return }
                    self.engines?.report(BeforeUnloadAnswered(pageID: pageID, proceeds: proceeds), from: self)
                }
                return
            }
        #endif
        engines?.report(BeforeUnloadAnswered(pageID: pageID, proceeds: true), from: self)
    }
}
