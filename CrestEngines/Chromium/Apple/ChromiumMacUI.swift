#if CREST_CHROMIUM_HOST
import AppKit

/// Crest's own UI, as Chromium's Mac shell asks for it: its windows, the
/// application's quit, reopen and external opens, system sign-in, and what the
/// engine's browser window asks of Crest's. The root answers every one.
@MainActor
final class ChromiumMacUI: NSObject, CrestMacUI {
    // MARK: - Windows

    func window(id: UUID?) -> NSWindow? {
        CrestChromiumRoot.window(for: id)
    }

    func reserveEngineWindow(profile: UUID, ownWindow: Bool) -> (any CrestEngineWindowPlacement)? {
        CrestChromiumRoot.reserveEngineWindow(forProfile: profile, ownWindow: ownWindow).map {
            Placement(window: $0.window, space: $0.space)
        }
    }

    func presentEngineWindow(_ windowID: UUID, space spaceID: UUID, focused: Bool) {
        CrestChromiumRoot.presentEngineWindow(windowID, space: spaceID, focused: focused)
    }

    // MARK: - Application

    func deferQuit() -> Bool { CrestChromiumRoot.deferQuit() }

    func reopen() -> Bool { CrestChromiumRoot.reopen() }

    func openExternal(_ urls: [URL]) -> Bool { CrestChromiumRoot.openExternalURLs(urls) }

    func openAuthenticationSession(_ url: URL, window windowID: UUID) -> Bool {
        CrestChromiumRoot.openAuthenticationSession(url, window: windowID)
    }

    func closeAuthenticationSession(window windowID: UUID) {
        CrestChromiumRoot.closeAuthenticationSession(windowID)
    }

    // MARK: - The engine's browser window

    func handleShortcut(_ event: NSEvent) -> Bool { CrestChromiumRoot.handleShortcutEvent(event) }

    func focusLocation() { CrestChromiumRoot.focusLocation() }

    func bookmarkActivePage() { CrestChromiumRoot.bookmarkActivePage() }

    func translatePage() { CrestChromiumRoot.translatePage() }

    func translate(_ text: String) { CrestChromiumRoot.translateText(text) }

    func showTabSearch() { CrestChromiumRoot.showTabSearch() }

    func showUnavailable(_ feature: UnavailableEngineFeature) {
        CrestChromiumRoot.showNativeNotice(feature.message, icon: feature.symbol)
    }

    func showEngineNotice(_ message: String, kind: EngineNoticeKind) {
        CrestChromiumRoot.showNativeNotice(message, icon: kind == .linkCopied ? "link" : "checkmark.circle")
    }

    // MARK: - Pages

    func addPageMenuItems(to menu: NSMenu, page pageID: UUID, link: URL?, selection: String?) {
        CrestChromiumRoot.chromiumEngine?.page(pageID)?.addMenuItems(to: menu, link: link, selection: selection)
    }

    func beginLinkDrag(_ url: URL, title: String, page pageID: UUID) -> Bool {
        CrestChromiumRoot.chromiumEngine?.page(pageID)?.beginLinkDrag(url, title: title) == true
    }

    private final class Placement: NSObject, CrestEngineWindowPlacement {
        let window: UUID
        let space: UUID
        init(window: UUID, space: UUID) {
            self.window = window
            self.space = space
        }
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
        case .autofillReauthentication: String(localized: "Autofill reauthentication is not available in Crest yet.")
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
