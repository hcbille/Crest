import Foundation

/// Where the Apple Passwords vault gets logins and passwords. The helper is
/// the real source; tests stand in a fake.
@MainActor
protocol ApplePasswordsCredentialSource: AnyObject, Sendable {
    /// The usernames saved for the origin's host. Throws unless the origin is
    /// https and the core's answer for the Space allows the helper.
    func logins(
        for origin: CredentialOrigin,
        support: ApplePasswordsSupport
    ) async throws -> ApplePasswordsLoginNamesRequest.Logins
    /// The password saved for `username` on the origin's host, under the same rules.
    func password(
        for origin: CredentialOrigin,
        username: String,
        support: ApplePasswordsSupport
    ) async throws -> String
}
