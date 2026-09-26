import Foundation

#if os(macOS)
import AppKit
typealias BrowserEngineView = NSView
#else
import UIKit
typealias BrowserEngineView = UIView
#endif

/// The native page port used by the existing UI: the engine's view and what it
/// shows. Everything the platform asks of the page's engine goes through its
/// `EnginePage`; portable session commands never receive a platform view.
@MainActor
protocol BrowserPageEngine: AnyObject {
    var registration: BrowserAdapterRegistration { get }
    var nativeView: BrowserEngineView { get }
    var backHistory: [BrowserNavigationHistoryItem] { get }
    var forwardHistory: [BrowserNavigationHistoryItem] { get }
    /// The engine's own document URL, which can run ahead of the URL the page
    /// last observed; nil before anything loaded.
    var currentURL: URL? { get }
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }
    /// True when the engine reports each navigation's state itself, so the page
    /// takes history availability and failures from those reports instead of
    /// deriving them from navigation callbacks.
    var reportsNavigationState: Bool { get }
    /// Brings supplemental history up to date with the engine's own list and
    /// answers the URL of its current entry.
    @discardableResult func synchronizeHistory() -> URL?
    func load(_ request: URLRequest)
    /// One-shot, engine-owned request metadata for a newly created native page.
    /// Tokens never enter the core session, persistence or sync.
    func stageNavigation(_ navigation: BrowserEngineNavigation, expecting url: URL) -> Bool
    /// Content bridges run by the engine itself, or nil when the page installs
    /// them through the engine's own API.
    var contentScripting: (any BrowserPageContentScripting)? { get }
    /// Runs `body` as an async function in a world of the main frame's current
    /// document that the page cannot see; nil when it produced no value.
    func evaluateInMainFrame(_ body: String) async -> Any?
    #if os(macOS)
    /// The engine's own print operation for its view, a page at a time; nil
    /// when the page prints from the PDF its engine exports.
    func printOperation(with info: NSPrintInfo) -> NSPrintOperation?
    #endif
}

extension BrowserPageEngine {
    var reportsNavigationState: Bool { false }
    @discardableResult func synchronizeHistory() -> URL? { nil }
    func stageNavigation(_ navigation: BrowserEngineNavigation, expecting url: URL) -> Bool { false }
    var contentScripting: (any BrowserPageContentScripting)? { nil }
    func evaluateInMainFrame(_ body: String) async -> Any? {
        await contentScripting?.callAsyncJavaScriptInMainFrame(body)
    }
    #if os(macOS)
    func printOperation(with info: NSPrintInfo) -> NSPrintOperation? { nil }
    #endif
}

struct BrowserEngineNavigation: Equatable, Sendable {
    let implementation: BrowserEngineImplementation
    let token: String
}
