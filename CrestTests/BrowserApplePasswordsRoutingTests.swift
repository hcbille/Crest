import Foundation
import XCTest

@testable import Crest

/// A row fills only through the vault that issued it, and Apple Passwords'
/// rows stay out of everything that is not a suggestion.
@MainActor
final class BrowserApplePasswordsRoutingTests: XCTestCase {
    private let origin = CredentialOrigin(scheme: "https", host: "accounts.crest.test", port: 443)

    func testARowFillsOnlyThroughTheVaultThatIssuedItAndAppleRowsStayOutOfSavedPasswords() async throws {
        var seed = SessionState.Seed.preview
        seed.spaces[0].settings.credentialPreferences = Self.preferences(usesApplePasswords: true)
        let space = seed.spaces[0]
        let crestVault = InMemoryCredentialVault()
        let store = BrowserStore(seed: seed, credentialVault: crestVault)
        let source = FakeAppleSource(logins: ["apple-user"], password: "apple-secret")
        store.applePasswords = FakeAppleAccess(core: store.core, source: source)
        let crest = BrowserCredential(
            descriptor: CredentialDescriptor(
                spaceID: space.id, origin: origin, username: "crest-user",
                createdAt: Date(timeIntervalSince1970: 1_000)),
            password: "crest-secret")
        try await crestVault.save(crest, in: space.id)

        let offer = try await store.credentialOffer(for: origin, in: space.id)
        let apple = try XCTUnwrap(offer.suggestions.first { $0.provider == .applePasswords })
        let ownRow = try XCTUnwrap(offer.suggestions.first { $0.provider == .crestPasswords })
        XCTAssertEqual(apple.descriptor.username, "apple-user")
        XCTAssertEqual(ownRow.descriptor.id, crest.descriptor.id)

        let appleFill = try await store.credential(for: apple, in: space.id)
        let crestFill = try await store.credential(for: ownRow, in: space.id)
        XCTAssertEqual(appleFill?.password, "apple-secret")
        XCTAssertEqual(crestFill?.password, "crest-secret")

        // An identifier the other vault never issued reads nothing.
        let readsBefore = source.passwordReads
        let crestIDAsApple = BrowserCredentialSuggestion(descriptor: crest.descriptor, provider: .applePasswords)
        let appleIDAsCrest = BrowserCredentialSuggestion(descriptor: apple.descriptor, provider: .crestPasswords)
        let crestAsApple = try await store.credential(for: crestIDAsApple, in: space.id)
        let appleAsCrest = try await store.credential(for: appleIDAsCrest, in: space.id)
        XCTAssertNil(crestAsApple)
        XCTAssertNil(appleAsCrest)
        XCTAssertEqual(source.passwordReads, readsBefore)

        // Apple Passwords' rows are not saved passwords and never match a save.
        let saved = try await store.savedCredentialDescriptors(in: space.id)
        XCTAssertEqual(saved.map(\.id), [crest.descriptor.id])
        let candidate = BrowserCredentialSaveCandidate(
            id: UUID(), origin: origin, topLevelOrigin: origin, username: "apple-user", password: "apple-secret",
            passwordKind: .current, isCrossOriginFrame: false, submittedAt: .now)
        let plan = try await store.credentialSavePlan(for: candidate, in: space.id)
        XCTAssertTrue(plan is BrowserCredentialCreatePlan)
    }

    func testAPrivateWindowNeverListsApplePasswordsRows() async throws {
        let store = BrowserStore.privateBrowsing(core: .hostingPages())
        let spaceID = try XCTUnwrap(store.shownSpace?.id)
        let source = FakeAppleSource(logins: ["apple-user"], password: "apple-secret")
        store.applePasswords = FakeAppleAccess(core: store.core, source: source)
        store.updateCredentialPreferences(Self.preferences(usesApplePasswords: true), in: spaceID)
        XCTAssertEqual(store.shownSpace?.settings.credentialPreferences.usesApplePasswords, true)

        let offer = try await store.credentialOffer(for: origin, in: spaceID)

        XCTAssertTrue(offer.suggestions.isEmpty)
        XCTAssertFalse(offer.offersApplePasswordsPairing)
        XCTAssertEqual(source.loginReads, 0)
    }

    private static func preferences(usesApplePasswords: Bool) -> CredentialPreferences {
        CredentialPreferences(
            isEnabled: true, syncsCrestPasswordsWithICloud: false, alsoOffersSaveToSystemPasswords: false,
            usesApplePasswords: usesApplePasswords)
    }
}

// MARK: - Fakes

@MainActor
private final class FakeAppleSource: ApplePasswordsCredentialSource {
    private let logins: [String]
    private let password: String
    private(set) var loginReads = 0
    private(set) var passwordReads = 0

    init(logins: [String], password: String) {
        self.logins = logins
        self.password = password
    }

    func logins(for origin: CredentialOrigin, support: ApplePasswordsSupport) async throws
        -> ApplePasswordsLoginNamesRequest.Logins
    {
        loginReads += 1
        return ApplePasswordsLoginNamesRequest.Logins(usernames: logins, neverSaves: false)
    }

    func password(for origin: CredentialOrigin, username: String, support: ApplePasswordsSupport) async throws -> String
    {
        passwordReads += 1
        return password
    }
}

/// A paired helper in a Mac launch, whose availability the real core decides
/// from what the store passes in.
@MainActor
private final class FakeAppleAccess: BrowserApplePasswordsAccess {
    let vault: any CredentialVault
    private let core: CrestCore

    init(core: CrestCore, source: FakeAppleSource) {
        self.core = core
        vault = ApplePasswordsCredentialVault(source: source) { _ in
            ApplePasswordsSupport(status: .available, offersToTurnOffExtension: false)
        }
    }

    func support(
        for space: BrowserSpaceIdentity, preferences: CredentialPreferences, isPrivateBrowsing: Bool
    ) -> ApplePasswordsSupport? {
        try? core.query(
            ApplePasswordsAvailability(
                isMacPlatform: true, hasManagedBrowserCapability: true, isLaunchIsolated: false,
                isPrivateBrowsing: isPrivateBrowsing, spaceCredentialsEnabled: preferences.isEnabled,
                spaceUsesApplePasswords: preferences.usesApplePasswords, applePasswordsExtensionEnabled: false,
                helper: .paired))
    }

    func couldStartHelper(
        for space: BrowserSpaceIdentity, preferences: CredentialPreferences, isPrivateBrowsing: Bool
    ) -> Bool { false }

    func start(support: ApplePasswordsSupport) async {}

    func requestPairingCode(support: ApplePasswordsSupport) async -> BrowserApplePasswordsPairingOutcome { .failed }

    func completePairing(code: String, support: ApplePasswordsSupport) async -> BrowserApplePasswordsPairingOutcome {
        .failed
    }

    func cancelPairing() async {}

    func rowsWereShown(support: ApplePasswordsSupport, in space: BrowserSpaceIdentity) {}

    func turnOffExtension(in space: BrowserSpaceIdentity) {}
}
