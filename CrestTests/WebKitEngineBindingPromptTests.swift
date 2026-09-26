import WebKit
import XCTest

@testable import Crest

/// A question a WebKit page asks travels through the core: the page's host
/// shows it once the core asks the person, and the answer the core settles
/// reaches WebKit, a sign-in's credential and a site's permission included. WebKit requires an answer to every question,
/// so a page that closes answers what it still asks as declined.
@MainActor
final class WebKitEngineBindingPromptTests: XCTestCase {
    func testAScriptDialogReachesItsHostThroughTheCoreAndItsAnswerReachesWebKit() throws {
        let (browser, opened) = try openPage()
        let host = PromptHost()
        opened.webKit.presenter = host
        var answer: (accepted: Bool, text: String?)?

        opened.webKit.ask(
            ScriptDialogQuestion(kind: .prompt, message: "Name?", defaultText: "", sourceURL: "https://prompt.crest.test/")
        ) { answer = ($0, $1) }
        browser.core.drain()
        let asked = try XCTUnwrap(host.asked.first)
        XCTAssertEqual(asked.question.message, "Name?")
        XCTAssertNil(answer, "WebKit waits until the core settles the question.")

        opened.core.answer(AnswerScriptDialog(promptID: asked.promptID, accepted: true, text: "Crest"))
        XCTAssertEqual(answer?.accepted, true)
        XCTAssertEqual(answer?.text, "Crest")
        opened.core.release(keepingState: false)
    }

    func testAPageThatClosesAnswersWhatItStillAsksAsDeclined() throws {
        let (browser, opened) = try openPage()
        let host = PromptHost()
        opened.webKit.presenter = host
        var answer: (accepted: Bool, text: String?)?
        opened.webKit.ask(
            ScriptDialogQuestion(kind: .confirm, message: "Sure?", defaultText: "", sourceURL: "https://confirm.crest.test/")
        ) { answer = ($0, $1) }
        browser.core.drain()
        XCTAssertEqual(host.asked.count, 1)
        XCTAssertNil(answer)

        opened.core.release(keepingState: false)

        XCTAssertEqual(answer?.accepted, false)
        XCTAssertNil(answer?.text)
    }

    func testASignInReachesItsHostThroughTheCoreAndItsCredentialReachesWebKit() throws {
        let (browser, opened) = try openPage()
        let host = PromptHost()
        opened.webKit.presenter = host
        var answer: AuthenticationCredential??
        opened.webKit.ask(
            AuthenticationQuestion(
                url: "https://sign-in.crest.test/", host: "sign-in.crest.test", port: 443, realm: "Staff", scheme: .basic,
                isProxy: false, previousFailures: 0)
        ) { answer = .some($0) }
        browser.core.drain()
        let asked = try XCTUnwrap(host.signIns.first)
        XCTAssertEqual(asked.question.realm, "Staff")

        let credential = AuthenticationCredential(username: "crest", password: "secret")
        opened.core.answer(AnswerAuthentication(promptID: asked.promptID, credential: credential))
        XCTAssertEqual(answer, .some(credential))
        opened.core.release(keepingState: false)
    }

    func testAPermissionRequestReachesItsHostThroughTheCoreAndTheAnswerReachesWebKit() throws {
        let (browser, opened) = try openPage()
        let host = PromptHost()
        opened.webKit.presenter = host
        let origin = SiteOrigin(scheme: "https", host: "camera.crest.test", port: 443)
        var answer: Bool?
        opened.webKit.ask(PermissionQuestion(permission: .camera, origin: origin, topLevelOrigin: origin)) { answer = $0 }
        browser.core.drain()
        let asked = try XCTUnwrap(host.permissions.first)
        XCTAssertEqual(asked.question.permission, .camera)

        opened.core.answer(AnswerPermission(promptID: asked.promptID, grants: true, remembers: false))
        XCTAssertEqual(answer, true)
        opened.core.release(keepingState: false)
    }

    /// A page the core opened on WebKit for a tab of a new window's Space.
    private func openPage() throws -> (BrowserStore, (core: CorePage, webKit: WebKitEnginePage)) {
        let tab = BrowserTab.startPage()
        let space = BrowserSpace(
            id: SpaceID(), profile: BrowsingProfile(), name: "Prompts", symbol: "circle", accent: .indigo, folders: [],
            tabs: [tab])
        let browser = BrowserStore.hostingPages(BrowserSession(spaces: [space]))
        let opened = try XCTUnwrap(
            browser.openWebKitPage(in: space.id, for: tab.id, webKit: WebKitPageInputs(websiteDataStore: .nonPersistent())))
        return (browser, opened)
    }
}

/// Records the questions the core asks the person about a page.
@MainActor
private final class PromptHost: BrowserPromptPresenting {
    private(set) var asked: [ScriptDialogAsked] = []
    private(set) var signIns: [AuthenticationAsked] = []
    private(set) var permissions: [PermissionAsked] = []

    func ask(_ asked: ScriptDialogAsked, dismissal: BrowserPromptDismissal) {
        self.asked.append(asked)
    }

    func ask(_ asked: AuthenticationAsked, dismissal: BrowserPromptDismissal) {
        signIns.append(asked)
    }

    func ask(_ asked: PermissionAsked, dismissal: BrowserPromptDismissal) {
        permissions.append(asked)
    }
}
