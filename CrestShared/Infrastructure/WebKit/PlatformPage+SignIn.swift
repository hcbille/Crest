import Foundation
import WebKit

/// A server's request for a user name and password, answered through the core.
extension BrowserPlatformPage {
    /// Answers `challenge` for a load of this page. A challenge the core's
    /// rules prompt for goes to the core as a question about `webKitPage`,
    /// which the page's Space's saved sign-in or the person answers; one the
    /// rules leave to the system, or cancel, never reaches it.
    func answerSignIn(
        _ challenge: URLAuthenticationChallenge, from webKitPage: WebKitEnginePage?,
        completionHandler: @escaping @MainActor @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        switch BrowserCorePolicy.authenticationHandling(for: BrowserAuthenticationChallenge(challenge)) {
        case .performDefaultHandling:
            completionHandler(.performDefaultHandling, nil)
        case .cancel:
            httpAuthenticationSession.authenticationFailed()
            completionHandler(.cancelAuthenticationChallenge, nil)
        case .promptForCredentials:
            guard let webKitPage, let question = AuthenticationQuestion(challenge) else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            webKitPage.ask(question) { credential in
                guard let credential else {
                    completionHandler(.cancelAuthenticationChallenge, nil)
                    return
                }
                completionHandler(
                    .useCredential,
                    URLCredential(user: credential.username, password: credential.password, persistence: .none))
            }
        }
    }
}
