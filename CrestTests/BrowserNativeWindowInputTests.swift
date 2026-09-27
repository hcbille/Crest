import AppKit
import XCTest

@testable import Crest

@MainActor
final class BrowserNativeWindowInputTests: XCTestCase {
    func testBrowserChromeKeepsTheNativeTitleBarAndControls() throws {
        let window = makeWindow()
        defer { window.close() }
        let content = try XCTUnwrap(window.contentView)
        let buttons = BrowserNativeWindowControlsPolicy.buttonTypes.compactMap(window.standardWindowButton)
        let input = NSTextField(frame: NSRect(x: 350, y: 560, width: 200, height: 28))
        content.addSubview(input)
        let chrome = BrowserNativeWindowControlsHostView()
        content.addSubview(chrome)
        window.layoutIfNeeded()

        // The title bar drags and double-clicks as the system's does; content
        // under it still receives its own clicks.
        XCTAssertTrue(window.isMovable)
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertTrue(content.hitTest(NSPoint(x: 400, y: 574)) === input)
        for (type, button) in zip(BrowserNativeWindowControlsPolicy.buttonTypes, buttons) {
            XCTAssertTrue(window.standardWindowButton(type) === button)
            XCTAssertTrue(button.isEnabled)
        }

        chrome.isVisible = false
        chrome.sidebarOnRight = true
        chrome.applyBrowserChrome()
        XCTAssertTrue(window.isMovable)
        XCTAssertTrue(content.hitTest(NSPoint(x: 400, y: 574)) === input)
    }

    func testAPageUnderTheTitleBarKeepsItsMouseDowns() {
        let host = BrowserWebHostView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let selector = NSSelectorFromString("_opaqueRectForWindowMoveWhenInTitlebar")
        typealias OpaqueRect = @convention(c) (AnyObject, Selector) -> NSRect

        // Neither AppKit nor the window server may start a window drag from a
        // page: the whole page is closed to it.
        XCTAssertFalse(host.mouseDownCanMoveWindow)
        XCTAssertTrue(host.responds(to: selector))
        let opaqueRect = unsafeBitCast(host.method(for: selector), to: OpaqueRect.self)(host, selector)
        XCTAssertEqual(opaqueRect, host.bounds)
    }

    func testLeavingAWindowKeepsTheFullscreenStateAppKitGaveIt() {
        let windowed: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let chrome = windowed.union(.fullSizeContentView)

        XCTAssertEqual(
            BrowserNativeWindowControlsPolicy.restoredStyleMask(
                original: windowed, current: chrome.union(.fullScreen)),
            windowed.union(.fullScreen))
        XCTAssertEqual(
            BrowserNativeWindowControlsPolicy.restoredStyleMask(
                original: windowed.union(.fullScreen), current: chrome),
            windowed)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        return window
    }
}
