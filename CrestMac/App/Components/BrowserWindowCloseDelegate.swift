import AppKit

/// Stands between AppKit and the delegate SwiftUI gave one of its windows, so
/// the window's close gate decides whether a close the person asked for goes
/// ahead. Every other message reaches SwiftUI's delegate unchanged, and the
/// window gets that delegate back once this stands aside. A window only holds
/// its delegate weakly, so whoever installs this keeps it.
@MainActor
final class BrowserWindowCloseDelegate: NSObject, NSWindowDelegate {
    // MARK: - Variables

    private let gate: BrowserWindowCloseGate
    private weak var window: NSWindow?
    /// The window's own delegate, which its owner keeps alive. AppKit asks
    /// which messages it answers from its own thread's calls into this object.
    private nonisolated(unsafe) weak var owner: NSObject?

    // MARK: - Initializers

    init(gate: BrowserWindowCloseGate) {
        self.gate = gate
    }

    // MARK: - Actions - Installation

    /// Stands between `window` and its delegate, unless it already does,
    /// leaving any window it stood in front of before.
    func install(on window: NSWindow) {
        guard window.delegate !== self else { return }
        if self.window !== window { uninstall() }
        owner = window.delegate as? NSObject
        self.window = window
        window.delegate = self
    }

    /// Gives the window its own delegate back.
    func uninstall() {
        if let window, window.delegate === self { window.delegate = owner as? NSWindowDelegate }
        window = nil
        owner = nil
    }

    // MARK: - Actions - Closing

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if (owner as? NSWindowDelegate)?.windowShouldClose?(sender) == false { return false }
        return gate.mayClose { [weak sender] in sender?.close() }
    }

    // MARK: - Actions - Forwarding

    nonisolated override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || owner?.responds(to: selector) == true
    }

    nonisolated override func forwardingTarget(for selector: Selector!) -> Any? {
        if let owner, owner.responds(to: selector) { return owner }
        return super.forwardingTarget(for: selector)
    }
}
