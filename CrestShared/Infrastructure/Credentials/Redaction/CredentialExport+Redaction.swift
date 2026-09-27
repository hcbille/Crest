import Foundation

/// Carries passwords to or from the core's password files, so it names no
/// secret when printed, logged or dumped.
extension CredentialExport: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String { "CredentialExport(credentials: \(credentials.count), spaceName: \(spaceName))" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}
