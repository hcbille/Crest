import Foundation

// MARK: - Suggestion Loading

extension BrowserStore: BrowserCredentialSuggestionLoading {
    /// Crest's own passwords for the site, then Apple Passwords' when the Space
    /// uses them and the core allows it. Apple Passwords never fails the list:
    /// a lookup that fails leaves Crest's rows and is logged.
    func credentialOffer(
        for origin: CredentialOrigin,
        in spaceID: UUID
    ) async throws -> BrowserCredentialOffer {
        guard let url = URL(string: origin.description) else {
            throw CredentialVaultError.invalidOrigin
        }
        let crest = try await credentialSuggestions(for: url, in: spaceID)
        var offer = BrowserCredentialOffer(
            suggestions: crest.map { BrowserCredentialSuggestion(descriptor: $0, provider: .crestPasswords) },
            offersApplePasswordsPairing: false)
        guard origin.isSecure, let access = applePasswords, var support = applePasswordsSupport(in: spaceID) else {
            return offer
        }
        if support.status.startsHelper {
            await access.start(support: support)
            // The helper's state is part of the core's question.
            guard let started = applePasswordsSupport(in: spaceID) else { return offer }
            support = started
        }
        offer.offersApplePasswordsPairing = support.status.needsPairing
        guard support.status.offersApplePasswords, let space = spaceModel(spaceID) else { return offer }
        do {
            let apple = try await access.vault.descriptors(matching: origin, in: spaceID)
            offer.suggestions += apple.map { BrowserCredentialSuggestion(descriptor: $0, provider: .applePasswords) }
            if !apple.isEmpty { access.rowsWereShown(support: support, in: space.identity) }
        } catch {
            DiagnosticLog.applePasswords.error("Apple Passwords suggestions failed: \(DiagnosticLog.describe(error))")
        }
        return offer
    }

    func requestApplePasswordsPairingCode(in spaceID: UUID) async -> BrowserApplePasswordsPairingOutcome {
        guard let access = applePasswords, let support = applePasswordsSupport(in: spaceID),
            support.status.needsPairing
        else { return .failed }
        return await access.requestPairingCode(support: support)
    }

    func completeApplePasswordsPairing(code: String, in spaceID: UUID) async -> BrowserApplePasswordsPairingOutcome {
        guard let access = applePasswords, let support = applePasswordsSupport(in: spaceID),
            support.status.needsPairing
        else { return .failed }
        return await access.completePairing(code: code, support: support)
    }

    func cancelApplePasswordsPairing() async {
        await applePasswords?.cancelPairing()
    }
}

// MARK: - Routing and availability

extension BrowserStore {
    /// The saved account a suggestion stands for, read from the vault that
    /// issued it. An identifier one vault issued is unknown to the other, so a
    /// row never fills through a vault that did not list it.
    func credential(for suggestion: BrowserCredentialSuggestion, in spaceID: UUID) async throws -> BrowserCredential? {
        guard spaceModel(spaceID) != nil else {
            throw CredentialVaultError.missingSpace
        }
        let vault = suggestion.provider.keepsSpaceVault ? credentialVault : applePasswords?.vault
        return try await vault?.credential(id: suggestion.id, in: spaceID)
    }

    /// The core's answer for the Space, or nil on a store without Apple
    /// Passwords or when the core cannot answer.
    func applePasswordsSupport(in spaceID: UUID) -> ApplePasswordsSupport? {
        guard let space = spaceModel(spaceID) else { return nil }
        return applePasswords?.support(
            for: space.identity, preferences: space.settings.credentialPreferences,
            isPrivateBrowsing: isPrivateBrowsing)
    }

    /// Whether the Space's settings offer Apple Passwords: this launch could
    /// start the helper for a Space that turned it on.
    func offersApplePasswordsSetting(in space: SpaceModel) -> Bool {
        applePasswords?.couldStartHelper(
            for: space.identity, preferences: space.settings.credentialPreferences,
            isPrivateBrowsing: isPrivateBrowsing) ?? false
    }
}
