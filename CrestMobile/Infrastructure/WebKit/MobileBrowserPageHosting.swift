import Dispatch
import Observation
import UIKit
import UniformTypeIdentifiers
import WebKit

/// The tab-level operations a page needs from whatever owns it.
/// `window.close()` arrives while a WebKit delegate callback is on the stack;
/// the page itself defers teardown requests until that callback has unwound.
@MainActor
protocol MobileBrowserPageHosting: AnyObject {
    /// Starts the original request in its newly registered tab, independently
    /// of whether the shared focus policy selects it, on the engine of page
    /// `opener`, which followed the link.
    func loadOpenedLink(
        _ registration: BrowserModifiedLinkRegistration, request: URLRequest, selecting: Bool, opener: UUID)

    /// Honors `window.close()` for a page the web content itself opened.
    func closeWebContentInitiatedPage(_ page: MobileBrowserPage)

    /// Retires an empty transient surface whose initial navigation became a download.
    func discardDownloadOnlyPage(_ page: MobileBrowserPage)

    /// Routes a pre-iOS 27 geolocation bridge message from a shared popup
    /// content controller to the page whose web view authored it.
    func routeGeolocationMessage(_ message: WKScriptMessage)

    /// Routes a blocked-popup bridge message from a shared popup content
    /// controller to the page whose web view actually authored it.
    func routeBlockedPopupMessage(_ message: WKScriptMessage)

    /// Routes a Media Session message received through an opener's shared
    /// content controller to the resident page that authored it.
    func routeMediaSessionMessage(_ message: WKScriptMessage)
}
