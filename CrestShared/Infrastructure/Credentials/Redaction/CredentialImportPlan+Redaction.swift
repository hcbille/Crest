import Foundation

/// Carries passwords to or from the core's password files, so it names no
/// secret when printed, logged or dumped.
extension CredentialImportPlan: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "CredentialImportPlan(format: \(format.name), groups: \(groups.count), rejections: \(rejections.count), warnings: \(warnings.count))"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}
