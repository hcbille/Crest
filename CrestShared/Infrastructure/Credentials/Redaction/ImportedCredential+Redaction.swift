import Foundation

/// Carries passwords to or from the core's password files, so it names no
/// secret when printed, logged or dumped.
extension ImportedCredential: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "ImportedCredential(row: \(rowNumber), origin: \(origin), username: <redacted>, password: <redacted>)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}
