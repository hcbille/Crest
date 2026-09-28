import AppKit

/// Owns the WebKit composition's launch and holds each quit until the core
/// agrees to it and the edits the app accepted are saved and staged for sync.
/// SwiftUI runs no termination hook that waits for queued work, so a quit
/// would otherwise end the process before the core's storage worker wrote the
/// newest revision or its stager staged it. Once the quit is allowed, the
/// core keeps the windows still open for the next launch, before SwiftUI
/// closes any of them.
@MainActor
final class CrestAppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Variables

    let launch = BrowserApplicationLaunch {
        try BrowserMacApplication()
    }

    // MARK: - Actions - Termination

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let application = launch.value else { return .terminateNow }
        // Until the reply, AppKit runs the main run loop in its modal panel
        // mode, which still drains the main queue and shows sheets: the core's
        // wake, the pages' and the person's answers, the drain that answers the
        // flush and the end of each turn all run there. A quit the core defers
        // while a Space is deleted is asked for again once the deletion moves on.
        application.quitPreparation.prepare(
            retry: { sender.terminate(nil) },
            completion: { allowed in
                guard allowed else {
                    sender.reply(toApplicationShouldTerminate: false)
                    return
                }
                // The core keeps the windows open now for the next launch
                // before SwiftUI closes any of them.
                application.rememberWindowsForLaunch()
                Task {
                    await application.flushPendingPersistenceBeforeQuit()
                    sender.reply(toApplicationShouldTerminate: true)
                }
            })
        return .terminateLater
    }

    // MARK: - Actions - Dock

    /// Crest's window commands and Spaces, which the Dock shows above the
    /// items macOS adds itself.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        guard let application = launch.value, application.presentsInstalledApplicationUI else { return nil }
        return application.dockMenu.menu()
    }
}
