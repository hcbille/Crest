import Foundation

/// Carries passwords to or from the core's password files, so it names no
/// secret when printed, logged or dumped.
extension CredentialImportGroup: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "CredentialImportGroup(origin: \(origin), username: <redacted>, candidates: \(candidates.map(\.rowNumber)))"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}
