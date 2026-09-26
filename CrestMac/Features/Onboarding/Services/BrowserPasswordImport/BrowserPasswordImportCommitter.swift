import Foundation

@MainActor
enum BrowserPasswordImportCommitter {
    static func commit(
        _ passwords: [BrowserImportedPassword],
        review: SetupImportReview,
        browser: BrowserStore
    ) async -> BrowserPasswordImportResult {
        guard !passwords.isEmpty else { return .empty }
        var recordsBySpace: [SpaceID: [BrowserCredentialCSVImportRecord]] = [:]
        var importedCount = 0
        var skippedCount = 0

        for (index, password) in passwords.enumerated() {
            let destinationIDs = destinationSpaceIDs(for: password, review: review)
            guard !destinationIDs.isEmpty else {
                skippedCount += 1
                continue
            }
            for spaceID in destinationIDs where browser.spaceModel(spaceID) != nil {
                recordsBySpace[spaceID, default: []].append(
                    BrowserCredentialCSVImportRecord(
                        rowNumber: index + 2,
                        displayName: password.origin.host,
                        origin: password.origin,
                        username: password.username,
                        password: password.password
                    )
                )
            }
        }

        for (spaceID, records) in recordsBySpace {
            guard let space = browser.spaceModel(spaceID) else {
                skippedCount += records.count
                continue
            }
            do {
                let existing = try await browser.credentialInventory(in: spaceID)
                let importPlan = BrowserCredentialImportPlan(
                    format: .browser,
                    records: records,
                    rejections: [],
                    existingCredentials: existing,
                    destination: BrowserSpaceRuntimeAssignment(spaceID: space.id, profileID: space.profileID),
                    synchronizesWithICloud: space.settings.credentialPreferences.syncsCrestPasswordsWithICloud,
                    core: browser.core
                )
                let resolution = try importPlan.resolvedInventory()
                if resolution.summary.acceptedCount > 0 {
                    try await browser.replaceCredentialInventory(
                        resolution.credentials,
                        in: spaceID
                    )
                }
                importedCount += resolution.summary.acceptedCount
                skippedCount += resolution.summary.skippedCount
            } catch {
                skippedCount += records.count
            }
        }
        return BrowserPasswordImportResult(
            importedCount: importedCount,
            skippedCount: skippedCount
        )
    }

    /// The Spaces `password` goes to once `review` is imported: the
    /// destination of each Space the review brings its passwords with that
    /// the password belongs with.
    static func destinationSpaceIDs(
        for password: BrowserImportedPassword,
        review: SetupImportReview
    ) -> [SpaceID] {
        let reviewed = review.spaces.filter(\.bringsPasswords)
        let destinations = Dictionary(
            reviewed.map { ($0.source.id, $0.destinationID ?? $0.source.id) }, uniquingKeysWith: { first, _ in first })
        return Array(
            Set(
                sourceSpaceIDs(
                    sourceApplication: password.sourceApplication,
                    sourceProfileName: password.sourceProfileName,
                    origin: password.origin,
                    among: reviewed.map(\.source)
                ).compactMap { destinations[$0] }))
    }

    /// The Spaces a browser brought that `candidate` belongs with, among
    /// `spaces`.
    static func sourceSpaceIDs(
        for candidate: BrowserPasswordImportCandidate,
        among spaces: [SpaceState]
    ) -> [SpaceID] {
        sourceSpaceIDs(
            sourceApplication: candidate.sourceApplication,
            sourceProfileName: candidate.sourceProfileName,
            origin: candidate.origin,
            among: spaces
        )
    }

    private static func sourceSpaceIDs(
        sourceApplication: ImportSource,
        sourceProfileName: String,
        origin: CredentialOrigin,
        among spaces: [SpaceState]
    ) -> [SpaceID] {
        let profileMatch = spaces.first {
            $0.settings.name.localizedCaseInsensitiveCompare(sourceProfileName)
                == .orderedSame
        }
        let hostMatches = spaces.filter { space in
            space.tabs.contains { tab in
                (tab.savedURL ?? tab.url).flatMap(URL.init(string:))?.host?.localizedCaseInsensitiveCompare(
                    origin.host
                ) == .orderedSame
            }
        }
        // A browser whose Spaces are its profiles gives each password to its
        // profile's Space; one that names its own Spaces, to every Space
        // holding the password's site.
        let matches: [SpaceState]
        if !sourceApplication.suppliesPasswords {
            matches = []
        } else if sourceApplication.namesItsSpaces {
            matches = hostMatches
        } else {
            matches =
                profileMatch.map { [$0] }
                ?? hostMatches.first.map { [$0] }
                ?? spaces.first.map { [$0] }
                ?? []
        }
        return matches.map(\.id)
    }
}
