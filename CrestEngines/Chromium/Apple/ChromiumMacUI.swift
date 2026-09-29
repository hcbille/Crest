#if CREST_CHROMIUM_HOST
    import AppKit

    /// Crest's own UI, as Chromium's Mac shell asks for it: its windows, the
    /// application's quit, reopen and external opens, system sign-in, and what
    /// the engine's browser window asks of Crest's. Crest's shared Mac shell
    /// answers each one; the composition answers what only Chromium asks.
    @MainActor
    final class ChromiumMacUI: NSObject, CrestMacUI {
        // MARK: - Types

        private final class Placement: NSObject, CrestEngineWindowPlacement {
            let window: UUID
            let space: UUID

            init(window: UUID, space: UUID) {
                self.window = window
                self.space = space
            }
        }

        // MARK: - Variables

        private var shell: BrowserMacShell? { ChromiumComposition.shell }

        // MARK: - Actions - Windows

        func window(id: UUID?) -> NSWindow? {
            shell?.window(for: id)
        }

        func restoredFrame(for window: NSWindow) -> NSRect {
            (window as? BrowserMacWindow)?.restoredFrame ?? window.frame
        }

        func wasZoomedBeforeFullScreen(_ window: NSWindow) -> Bool {
            (window as? BrowserMacWindow)?.wasZoomedBeforeFullScreen ?? false
        }

        func reserveEngineWindow(profile: UUID, ownWindow: Bool) -> (any CrestEngineWindowPlacement)? {
            shell?.reserveEngineWindow(forProfile: profile, ownWindow: ownWindow).map {
                Placement(window: $0.window, space: $0.space)
            }
        }

        func presentEngineWindow(_ windowID: UUID, space spaceID: UUID, focused: Bool) {
            shell?.presentEngineWindow(windowID, space: spaceID, focused: focused)
        }

        // MARK: - Actions - Application

        func deferQuit() -> Bool { ChromiumComposition.deferQuit() }

        func reopen() -> Bool { shell?.reopen() ?? false }

        func openExternal(_ urls: [URL]) -> Bool { shell?.openExternal(urls) ?? false }

        func dockMenu() -> NSMenu? { shell?.dockMenu() }

        func openAuthenticationSession(_ url: URL, window windowID: UUID) -> Bool {
            guard let host = ChromiumComposition.engineHost else { return false }
            return shell?.openAuthenticationSession(url, window: windowID) {
                host.cancelAuthenticationSession(window: windowID)
            } ?? false
        }

        func closeAuthenticationSession(window windowID: UUID) {
            shell?.closeAuthenticationSession(windowID)
        }

        // MARK: - Actions - The engine's browser window

        /// A key the engine is about to hand a page, which sees it first unless
        /// the core reserves its command from pages. The engine hands a key the
        /// page lets go to the menu bar.
        func handleShortcut(_ event: NSEvent) -> Bool { shell?.handleShortcut(event, pageSeesFirst: true) ?? false }

        func focusLocation() { shell?.focusLocation() }

        func bookmarkActivePage() { shell?.bookmarkActivePage() }

        func translatePage() { ChromiumComposition.translatePage() }

        func translate(_ text: String) { ChromiumComposition.translateText(text) }

        func showTabSearch() { shell?.showTabSearch() }

        func showUnavailable(_ feature: UnavailableEngineFeature) {
            ChromiumComposition.showNativeNotice(feature.message, icon: feature.symbol)
        }

        func showEngineNotice(_ message: String, kind: EngineNoticeKind) {
            ChromiumComposition.showNativeNotice(message, icon: kind == .linkCopied ? "link" : "checkmark.circle")
        }

        // MARK: - Actions - Pages

        func addPageMenuItems(to menu: NSMenu, page pageID: UUID, link: URL?, selection: String?) {
            ChromiumComposition.chromiumEngine?.page(pageID)?.addMenuItems(to: menu, link: link, selection: selection)
        }

        func beginLinkDrag(_ url: URL, title: String, page pageID: UUID) -> Bool {
            ChromiumComposition.chromiumEngine?.page(pageID)?.beginLinkDrag(url, title: title) == true
        }
    }

    extension UnavailableEngineFeature {
        fileprivate var message: String {
            switch self {
            case .autofill: String(localized: "Autofill is not connected in Crest yet.")
            case .addressAutofill: String(localized: "Address autofill is not available in Crest yet.")
            case .addressAutofillSignIn: String(localized: "Address autofill sign-in is not available in Crest yet.")
            case .autofillAI: String(localized: "Autofill with AI is not available in Crest yet.")
            case .autofillOffers: String(localized: "Autofill offers are not available in Crest yet.")
            case .autofillReauthentication:
                String(localized: "Autofill reauthentication is not available in Crest yet.")
            case .paymentAutofill: String(localized: "Payment autofill is not available in Crest yet.")
            case .virtualCardEnrollment: String(localized: "Virtual card enrollment is not available in Crest yet.")
            case .profiles: String(localized: "Profiles are not available in Crest yet.")
            case .eyeDropper: String(localized: "The eye dropper is not available in Crest yet.")
            case .caretBrowsing: String(localized: "Caret browsing is not available in Crest yet.")
            case .privateBrowsing: String(localized: "This private browsing option is not available in Crest yet.")
            case .chromeLabs: String(localized: "Chrome Labs is not available in Crest.")
            @unknown default: String(localized: "This is not available in Crest yet.")
            }
        }

        fileprivate var symbol: String {
            switch self {
            case .autofill: "person"
            case .addressAutofill: "person.text.rectangle"
            case .addressAutofillSignIn: "person.crop.circle.badge.plus"
            case .autofillAI: "sparkles"
            case .autofillOffers: "tag"
            case .autofillReauthentication: "lock.shield"
            case .paymentAutofill: "creditcard"
            case .virtualCardEnrollment: "creditcard.trianglebadge.exclamationmark"
            case .profiles: "person.crop.circle"
            case .eyeDropper: "eyedropper"
            case .caretBrowsing: "text.cursor"
            case .privateBrowsing: "eye.slash"
            case .chromeLabs: "flask"
            @unknown default: "info.circle"
            }
        }
    }
#endif
