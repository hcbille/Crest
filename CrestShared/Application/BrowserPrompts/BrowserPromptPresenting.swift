import Foundation

/// The platform's page, which shows the person the questions the core asks
/// about it and sends back their answers, whichever engine hosts it. Each
/// question closes once `dismissal` says it no longer waits.
@MainActor
protocol BrowserPromptPresenting: AnyObject {
    /// Shows a script dialog the page's document opened.
    func ask(_ asked: ScriptDialogAsked, dismissal: BrowserPromptDismissal)
}
