import AppKit
import SwiftUI

struct BrowserMacWindowAttachment: NSViewRepresentable {
    var prepare: (NSWindow) -> Void = { _ in }
    /// Decides whether the window may close when the person asks; without
    /// one, it closes at once.
    var closeGate: BrowserWindowCloseGate?
    let attach: (NSWindow) -> Void
    let focusChanged: (Bool) -> Void
    let close: () -> Void

    func makeNSView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.prepare = prepare
        view.closeGate = closeGate
        view.attach = attach
        view.focusChanged = focusChanged
        view.close = close
        return view
    }

    func updateNSView(_ view: AttachmentView, context: Context) {}

    final class AttachmentView: NSView {
        var prepare: ((NSWindow) -> Void)?
        var closeGate: BrowserWindowCloseGate?
        var attach: ((NSWindow) -> Void)?
        var focusChanged: ((Bool) -> Void)?
        var close: (() -> Void)?
        /// What asks `closeGate` for a window SwiftUI made, kept here because
        /// the window holds its delegate weakly.
        private var closeDelegate: BrowserWindowCloseDelegate?

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow !== window { closeDelegate?.uninstall() }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            guard let window else { return }
            prepare?(window)
            gateClosing(of: window)
            NotificationCenter.default.addObserver(
                self, selector: #selector(becameKey), name: NSWindow.didBecomeKeyNotification, object: window)
            NotificationCenter.default.addObserver(
                self, selector: #selector(resignedKey), name: NSWindow.didResignKeyNotification, object: window)
            NotificationCenter.default.addObserver(
                self, selector: #selector(willClose), name: NSWindow.willCloseNotification, object: window)
            // Scene registration and transfer can change observed models.
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window, self.window === window else { return }
                self.attach?(window)
                self.gateClosing(of: window)
            }
        }

        /// Puts `closeGate` in front of the window's close requests. A window
        /// that asks its own gate needs nothing more; one SwiftUI made gets a
        /// delegate in front of SwiftUI's, again whenever SwiftUI replaced it.
        private func gateClosing(of window: NSWindow) {
            guard let closeGate, !(window is any BrowserCloseGatedWindow) else { return }
            let delegate = closeDelegate ?? BrowserWindowCloseDelegate(gate: closeGate)
            closeDelegate = delegate
            delegate.install(on: window)
        }

        @objc private func becameKey() {
            if let window { gateClosing(of: window) }
            focusChanged?(true)
        }
        @objc private func resignedKey() { focusChanged?(false) }
        @objc private func willClose() { close?() }
    }
}
