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

// MARK: - Saving

extension BrowserStore {
    /// The core's answer for the Space when a captured password can be offered
    /// to Apple Passwords: the Space uses it, the core offers it (paired and
    /// available, never in a private window or an isolated launch), and the
    /// candidate's origin is https, and the helper can save the account (one
    /// without a username needs a helper that says it can). Nil means the save
    /// goes to Crest as usual.
    func applePasswordsSaveSupport(
        for candidate: BrowserCredentialSaveCandidate, in spaceID: UUID
    ) -> ApplePasswordsSupport? {
        guard candidate.origin.isSecure, !isPrivateBrowsing, let access = applePasswords,
            !candidate.username.isEmpty || access.savesAccountsWithoutUsername,
            spaceModel(spaceID)?.settings.credentialPreferences.usesApplePasswords == true,
            let support = applePasswordsSupport(in: spaceID), support.status.offersApplePasswords
        else { return nil }
        return support
    }

    /// Keeps a generated password before it is filled, so it is never lost.
    /// Where the Space's destination is Apple Passwords it is sent there; any
    /// failure, or an account without a username that the helper cannot save,
    /// keeps it in Crest's vault instead.
    /// - Returns: Whether it was sent to Apple Passwords rather than kept in Crest.
    func keepGeneratedPassword(_ candidate: BrowserCredentialSaveCandidate, in spaceID: UUID) async throws -> Bool {
        if applePasswordsSaveSupport(for: candidate, in: spaceID) != nil {
            do {
                try await commitApplePasswordsSave(candidate, in: spaceID)
                return true
            } catch {
                DiagnosticLog.applePasswords.error(
                    "Sending a generated password failed: \(DiagnosticLog.describe(error))")
            }
        }
        _ = try await commitCredentialSave(candidate, in: spaceID)
        return false
    }

    /// Sends the candidate to Apple Passwords for the frame origin it was
    /// captured for, and writes nothing to Crest's vault. Apple decides whether
    /// the account is new or changed, so Crest's own match is not consulted.
    func commitApplePasswordsSave(
        _ candidate: BrowserCredentialSaveCandidate,
        in spaceID: UUID,
        now: Date = .now
    ) async throws {
        try validateCredentialSaveCandidate(candidate, in: spaceID, now: now)
        guard let access = applePasswords, let support = applePasswordsSaveSupport(for: candidate, in: spaceID)
        else {
            throw CredentialVaultError.credentialManagerDisabled
        }
        try await access.save(candidate, support: support)
    }
}
