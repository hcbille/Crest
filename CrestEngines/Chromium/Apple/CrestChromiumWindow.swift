#if CREST_CHROMIUM_HOST
    import AppKit

    /// All native close routes, including accessibility and traffic-light actions,
    /// pass through close(), which asks the window's close gate first. AppKit
    /// still owns performClose and delegate checks.
    @MainActor
    final class CrestChromiumWindow: NSWindow, BrowserCloseGatedWindow {
        var closeGate: BrowserWindowCloseGate?

        override func close() {
            guard let closeGate else {
                super.close()
                return
            }
            guard closeGate.mayClose(then: { [weak self] in self?.closeAfterApproval() }) else { return }
            super.close()
        }

        /// Closes without asking: the gate approved it, or the host closes the
        /// window as part of something wider it already decided.
        func closeAfterApproval() { super.close() }
    }
#endif
