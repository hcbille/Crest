import Foundation

/// Carries passwords to or from the core's password files, so it names no
/// secret when printed, logged or dumped.
extension PasswordImportPreview: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String { "PasswordImportPreview(credentials: \(credentials.count), existing: \(existing.count))" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}
