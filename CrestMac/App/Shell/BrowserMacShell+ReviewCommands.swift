#if CREST_REVIEW_BUILD && DEBUG
    import AppKit

    // MARK: - Types

    /// A command a review pass posts to an isolated Debug review build, so it
    /// can load pages in the window's current tab and run Crest's own commands
    /// with no keystrokes and no accessibility driving. No other build
    /// listens.
    ///
    /// The notification's object is the command's verb, a space, then its
    /// argument:
    /// - `load <address>` loads the address in the current tab, as if typed.
    /// - `command <name>` runs the Crest command with that persisted shortcut
    ///   name, such as `back`, `reloadPage` or `webInspectorInstructions` (Show
    ///   Web Inspector). A name no command has does nothing.
    /// - `settings` opens Settings.
    ///
    /// Commands take the same route a person's do, so the window must be key:
    /// with no key window a window command does nothing.
    @MainActor
    private struct BrowserMacReviewCommand {
        // MARK: - Static Variables

        static let notificationName = Notification.Name("com.pauldavis.crest.review.command")

        static let load = BrowserMacReviewCommand(verb: "load") { shell, address in
            shell.activeActions?.pages.navigate(to: address)
        }
        static let command = BrowserMacReviewCommand(verb: "command") { shell, name in
            if let command = ShortcutCommand.named(name) { shell.perform(command) }
        }
        static let settings = BrowserMacReviewCommand(verb: "settings") { shell, _ in
            BrowserMacApplicationAction.settings.perform(in: shell)
        }
        static let all = [load, command, settings]

        // MARK: - Variables

        let verb: String
        private let run: @MainActor (BrowserMacShell, String) -> Void

        // MARK: - Initializers

        private init(verb: String, run: @escaping @MainActor (BrowserMacShell, String) -> Void) {
            self.verb = verb
            self.run = run
        }

        // MARK: - Actions - Running

        /// Runs the command `text` spells in `shell`; text that spells none
        /// does nothing.
        static func perform(_ text: String, in shell: BrowserMacShell) {
            let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
            guard let verb = parts.first, let command = all.first(where: { $0.verb == verb }) else { return }
            command.run(shell, parts.count > 1 ? parts[1] : "")
        }
    }

    extension BrowserMacShell {
        // MARK: - Actions - Review commands

        func listenForReviewCommands() {
            DistributedNotificationCenter.default().addObserver(
                forName: BrowserMacReviewCommand.notificationName, object: nil, queue: .main
            ) { [weak self] notification in
                guard let text = notification.object as? String else { return }
                MainActor.assumeIsolated {
                    guard let self else { return }
                    BrowserMacReviewCommand.perform(text, in: self)
                }
            }
        }
    }
#endif
