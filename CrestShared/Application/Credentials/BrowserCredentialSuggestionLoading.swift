import Foundation

@MainActor
protocol BrowserCredentialSuggestionLoading: AnyObject {
    func credentialOffer(
        for origin: CredentialOrigin,
        in spaceID: UUID
    ) async throws -> BrowserCredentialOffer

    /// Has Apple Passwords show a pairing code.
    func requestApplePasswordsPairingCode(in spaceID: UUID) async -> BrowserApplePasswordsPairingOutcome

    func completeApplePasswordsPairing(code: String, in spaceID: UUID) async -> BrowserApplePasswordsPairingOutcome

    /// The person dismissed the code entry: tells Apple Passwords to stop waiting for the code.
    func cancelApplePasswordsPairing() async
}
