import Foundation

/// The kind of form a saved login came from. Apple's extension names the kind
/// in the query identifier of a save, so each instance carries its own.
struct ApplePasswordsFormKind: Hashable, Sendable {
    // MARK: - Static Variables

    static let signIn = ApplePasswordsFormKind(queryID: .setPassword)
    static let signUp = ApplePasswordsFormKind(queryID: .newAccount)
    static let changePassword = ApplePasswordsFormKind(queryID: .changePassword)

    // MARK: - Variables

    /// The `QID` a save from this kind of form carries.
    let queryID: ApplePasswordsQueryID

    // MARK: - Initializers

    private init(queryID: ApplePasswordsQueryID) {
        self.queryID = queryID
    }
}
