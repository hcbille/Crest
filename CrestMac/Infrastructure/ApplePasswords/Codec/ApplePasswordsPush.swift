import Foundation

/// Something the helper announces without being asked. Either ends the paired
/// session: the helper no longer holds the key it was paired with.
struct ApplePasswordsPush: Hashable, Sendable {
    // MARK: - Static Variables

    static let passwordsDisabled = ApplePasswordsPush(name: "passwordsDisabled")
    static let reloginNeeded = ApplePasswordsPush(name: "reloginNeeded")

    // MARK: - Variables

    /// How the log names the push. Never a message's contents.
    let name: String

    // MARK: - Initializers

    private init(name: String) {
        self.name = name
    }
}
