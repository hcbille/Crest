import AppKit
import XCTest

@testable import Crest

@MainActor
final class BrowserNativeWindowInputTests: XCTestCase {
    func testTheWindowServerNeverDragsAWindowCrestsChromeStyles() throws {
        let window = makeWindow()
        defer { window.close() }
        let content = try XCTUnwrap(window.contentView)
        let buttons = BrowserNativeWindowControlsPolicy.buttonTypes.compactMap(window.standardWindowButton)
        let input = NSTextField(frame: NSRect(x: 350, y: 560, width: 200, height: 28))
        content.addSubview(input)
        let chrome = BrowserNativeWindowControlsHostView()
        content.addSubview(chrome)
        window.layoutIfNeeded()

        // The window server gets no title-bar strip to drag the window from,
        // so a page under the title bar keeps its presses; the native controls
        // stay as they are.
        XCTAssertFalse(window.isMovable)
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
        XCTAssertFalse(window.isMovable)
        XCTAssertTrue(content.hitTest(NSPoint(x: 400, y: 574)) === input)

        // A window Crest's chrome leaves moves as it did before.
        chrome.removeFromSuperview()
        XCTAssertTrue(window.isMovable)
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
