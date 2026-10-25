import Foundation

/// The Mac's Apple Passwords, as shared code reaches it. Every answer about
/// whether Apple Passwords may be used comes from the core's
/// `ApplePasswordsAvailability` query; this class supplies the launch's facts
/// and carries out what the core allows.
@MainActor
final class BrowserMacApplePasswords: BrowserApplePasswordsAccess {
    // MARK: - Variables

    let vault: any CredentialVault

    private let core: CrestCore
    private let helper: ApplePasswordsHelper
    private let launchEnvironment: BrowserLaunchEnvironment
    /// The standard windows' store, whose Spaces the vault answers for.
    private weak var browser: BrowserStore?
    private var spacesToldAboutExtension: Set<UUID> = []
    private var toldHelperIsUnavailable = false

    // MARK: - Initializers

    init(
        core: CrestCore, browser: BrowserStore, helper: ApplePasswordsHelper,
        launchEnvironment: BrowserLaunchEnvironment = .current
    ) {
        self.core = core
        self.browser = browser
        self.helper = helper
        self.launchEnvironment = launchEnvironment
        vault = ApplePasswordsCredentialVault(source: helper) { [weak browser, weak helper, weak core] spaceID in
            await Self.support(for: spaceID, browser: browser, helper: helper, core: core)
        }
        helper.onStateChange = { [weak self] state in self?.helperStateChanged(state) }
    }

    // MARK: - Actions - Availability

    func support(
        for space: BrowserSpaceIdentity, preferences: CredentialPreferences, isPrivateBrowsing: Bool
    ) -> ApplePasswordsSupport? {
        answer(
            helper: helper.state, space: space, preferences: preferences, isPrivateBrowsing: isPrivateBrowsing)
    }

    func couldStartHelper(
        for space: BrowserSpaceIdentity, preferences: CredentialPreferences, isPrivateBrowsing: Bool
    ) -> Bool {
        var turnedOn = preferences
        turnedOn.usesApplePasswords = true
        return answer(helper: .stopped, space: space, preferences: turnedOn, isPrivateBrowsing: isPrivateBrowsing)?
            .status.startsHelper ?? false
    }

    private func answer(
        helper state: ApplePasswordsHelper.State, space: BrowserSpaceIdentity, preferences: CredentialPreferences,
        isPrivateBrowsing: Bool
    ) -> ApplePasswordsSupport? {
        try? core.query(
            BrowserApplePasswordsSystem.availability(
                helper: state, preferences: preferences, isPrivateBrowsing: isPrivateBrowsing,
                applePasswordsExtensionEnabled: Self.isAppleExtensionEnabled(in: space),
                launchEnvironment: launchEnvironment))
    }

    /// The vault asks again for every read, with the Space as it is now.
    private static func support(
        for spaceID: UUID, browser: BrowserStore?, helper: ApplePasswordsHelper?, core: CrestCore?
    ) -> ApplePasswordsSupport? {
        guard let browser, let helper, let core, let space = browser.spaceModel(spaceID) else { return nil }
        let query = BrowserApplePasswordsSystem.availability(
            helper: helper.state, preferences: space.settings.credentialPreferences,
            isPrivateBrowsing: browser.isPrivateBrowsing,
            applePasswordsExtensionEnabled: isAppleExtensionEnabled(in: space.identity))
        return try? core.query(query)
    }

    /// Only the Chromium engine knows its extensions, and only from what it has
    /// already read for the Space.
    private static func isAppleExtensionEnabled(in space: BrowserSpaceIdentity) -> Bool {
        #if CREST_CHROMIUM_HOST
            return ChromiumComposition.extensions.isApplePasswordsExtensionEnabled(in: space)
        #else
            return false
        #endif
    }

    // MARK: - Actions - Helper

    func start(support: ApplePasswordsSupport) async {
        await helper.start(support: support)
    }

    func requestPairingCode(support: ApplePasswordsSupport) async -> BrowserApplePasswordsPairingOutcome {
        do {
            try await helper.requestPairingCode(support: support)
            return .codeShown
        } catch {
            return (error as? ApplePasswordsPairingError)?.outcome ?? .failed
        }
    }

    func completePairing(code: String, support: ApplePasswordsSupport) async -> BrowserApplePasswordsPairingOutcome {
        do {
            try await helper.completePairing(code: code, support: support)
            return .paired
        } catch {
            return (error as? ApplePasswordsPairingError)?.outcome ?? .failed
        }
    }

    func cancelPairing() async {
        helper.cancelPairing()
    }

    // MARK: - Actions - Saving

    var savesAccountsWithoutUsername: Bool { helper.savesAccountsWithoutUsername }

    func save(_ candidate: BrowserCredentialSaveCandidate, support: ApplePasswordsSupport) async throws {
        try await helper.save(
            candidate.username, candidate.password, for: candidate.origin,
            form: .capturing(candidate.passwordKind), support: support)
    }

    // MARK: - Actions - Notices

    func rowsWereShown(support: ApplePasswordsSupport, in space: BrowserSpaceIdentity) {
        guard support.offersToTurnOffExtension, spacesToldAboutExtension.insert(space.id).inserted else { return }
        BrowserNoticeCenter.shared.post(
            BrowserNotice(
                message: String(localized: "Apple’s iCloud Passwords extension is also on"),
                systemImage: "key.fill",
                action: BrowserNoticeAction(title: String(localized: "Turn Off")) { [weak self] in
                    self?.turnOffExtension(in: space)
                }))
    }

    func turnOffExtension(in space: BrowserSpaceIdentity) {
        #if CREST_CHROMIUM_HOST
            ChromiumComposition.extensions.command(
                .disable, extensionID: BrowserApplePasswordsSystem.appleExtensionID, space: space)
        #endif
    }

    /// Tells the person once per launch that the helper stopped being usable.
    private func helperStateChanged(_ state: ApplePasswordsHelper.State) {
        guard case .unavailable = state, !toldHelperIsUnavailable else { return }
        toldHelperIsUnavailable = true
        BrowserNoticeCenter.shared.post(
            BrowserNotice(message: String(localized: "Apple Passwords isn’t available"), systemImage: "key.fill"))
    }
}
