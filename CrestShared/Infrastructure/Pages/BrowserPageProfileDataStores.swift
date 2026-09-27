import WebKit

/// The per-profile engine state every page owner of one store family shares:
/// the certificate exceptions people accepted, and each private profile's
/// in-memory website data store.
@MainActor
final class BrowserPageProfileDataStores {
    // MARK: - Variables

    let serverTrustOverrides = BrowserServerTrustOverrideStore()
    /// Each private profile's WebKit website data store, by profile.
    private var ephemeral: [UUID: WKWebsiteDataStore] = [:]

    // MARK: - Actions - Stores

    /// The profile's in-memory website data store, made the first time a page
    /// of the profile asks for it.
    func ephemeralStore(for profileID: UUID) -> WKWebsiteDataStore {
        if let store = ephemeral[profileID] { return store }
        let store = WKWebsiteDataStore.nonPersistent()
        ephemeral[profileID] = store
        return store
    }

    /// Drops a private profile's website data along with its store.
    func releaseEphemeralStore(for profileID: UUID) {
        ephemeral.removeValue(forKey: profileID)
    }

    func releaseAllEphemeralStores() {
        ephemeral.removeAll()
    }
}
