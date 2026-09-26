import Foundation

// The records that carry passwords to and from the core's password files
// name no secret when printed, logged or dumped.

extension ImportedCredential: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "ImportedCredential(row: \(rowNumber), origin: \(origin), username: <redacted>, password: <redacted>)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}

extension ExistingCredential: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "ExistingCredential(id: \(id), origin: \(origin), username: <redacted>, password: <redacted>)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}

extension CredentialImportCandidate: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "CredentialImportCandidate(row: \(rowNumber), effect: \(effect.name), username: <redacted>, password: <redacted>)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}

extension CredentialImportGroup: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "CredentialImportGroup(origin: \(origin), username: <redacted>, candidates: \(candidates.map(\.rowNumber)))"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}

extension CredentialImportPlan: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "CredentialImportPlan(format: \(format.name), groups: \(groups.count), rejections: \(rejections.count), warnings: \(warnings.count))"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}

extension CredentialImportPreview: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "CredentialImportPreview(document: <\(document.count) bytes redacted>, existing: \(existing.count))"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}

extension PasswordImportPreview: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String { "PasswordImportPreview(credentials: \(credentials.count), existing: \(existing.count))" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}

extension ExportedCredential: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "ExportedCredential(id: \(id), origin: \(origin), username: <redacted>, password: <redacted>)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}

extension CredentialExport: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String { "CredentialExport(credentials: \(credentials.count), spaceName: \(spaceName))" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}

extension CredentialExportFile: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    var description: String {
        "CredentialExportFile(fileName: \(fileName), contents: <\(contents.count) bytes redacted>)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [], displayStyle: .struct) }
}
