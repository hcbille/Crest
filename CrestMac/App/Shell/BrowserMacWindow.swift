import AppKit

/// Every window the shell opens. All native close routes, including
/// accessibility and traffic-light actions, pass through `close()`, which asks
/// the window's close gate first; AppKit still owns `performClose` and the
/// delegate's checks.
@MainActor
final class BrowserMacWindow: NSWindow {
    // MARK: - Variables

    var closeGate: BrowserWindowCloseGate?
    /// What the window's content does with a mouse's Back and Forward
    /// buttons, while content that knows its pages is shown.
    weak var pointerNavigation: (any BrowserMacWindowPointerNavigation)?

    // MARK: - Actions - Closing

    override func close() {
        guard let closeGate else {
            super.close()
            return
        }
        guard closeGate.mayClose(then: { [weak self] in self?.closeAfterApproval() }) else { return }
        super.close()
    }

    /// Closes without asking: the gate approved it, or the shell closes the
    /// window as part of something wider it already decided.
    func closeAfterApproval() {
        super.close()
    }
}
