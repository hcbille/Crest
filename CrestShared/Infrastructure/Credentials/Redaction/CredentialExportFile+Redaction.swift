import Foundation

/// Carries passwords to or from the core's password files, so it names no
/// secret when printed, logged or dumped.
extension CredentialExportFile: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "CredentialExportFile(fileName: \(fileName), contents: <\(contents.count) bytes redacted>)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}
