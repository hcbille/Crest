import Foundation

/// What shared code may ask of Apple Passwords. Only the Mac implements it, and
/// every other platform leaves a store's access nil, so nothing here is
/// reachable from CrestMobile.
///
/// The Mac's implementation always gets its `ApplePasswordsSupport` from the
/// core's `ApplePasswordsAvailability` query. Shared code reads the core's
/// answer (`startsHelper`, `offersApplePasswords`, `needsPairing`) and never
/// reaches the helper or an engine itself.
@MainActor
protocol BrowserApplePasswordsAccess: AnyObject {
    /// The vault that issued the identifiers of Apple Passwords' rows. It
    /// serves suggestions and reads only; nothing is ever saved to it.
    var vault: any CredentialVault { get }

    /// The core's answer for a Space now; nil when the core cannot answer.
    func support(
        for space: BrowserSpaceIdentity, preferences: CredentialPreferences, isPrivateBrowsing: Bool
    ) -> ApplePasswordsSupport?

    /// Whether this launch could start the helper for a Space that turned
    /// Apple Passwords on, whatever the Space chose.
    func couldStartHelper(
        for space: BrowserSpaceIdentity, preferences: CredentialPreferences, isPrivateBrowsing: Bool
    ) -> Bool

    /// Starts the helper when `support` starts it. Asks only for what the
    /// helper supports and shows the person nothing.
    func start(support: ApplePasswordsSupport) async

    /// Has the helper show a pairing code in its own window.
    func requestPairingCode(support: ApplePasswordsSupport) async -> BrowserApplePasswordsPairingOutcome

    /// Pairs with the code the person read from the helper's window.
    func completePairing(code: String, support: ApplePasswordsSupport) async -> BrowserApplePasswordsPairingOutcome

    /// The person gave up on the code the helper shows. Does nothing when no code is waiting.
    func cancelPairing() async

    /// Apple Passwords' rows were just shown in the Space, so the Space may
    /// also be told about Apple's own extension.
    func rowsWereShown(support: ApplePasswordsSupport, in space: BrowserSpaceIdentity)

    /// Turns Apple's extension off in the Space.
    func turnOffExtension(in space: BrowserSpaceIdentity)
}
