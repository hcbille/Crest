import Foundation

extension EngineDownloadWarning {
    /// What the person is told about a download its engine warned about.
    var approvalMessage: String {
        switch self {
        case .insecureConnection:
            String(
                localized:
                    "This file was transferred over an insecure connection and could have been changed by someone else. Keep it only if you trust its source."
            )
        case .dangerousFile:
            String(localized: "This type of file can change your computer. Keep it only if you trust its source.")
        case .uncommonContent:
            String(localized: "This file is not commonly downloaded. The engine could not confirm that it is safe.")
        case .potentiallyUnwanted:
            String(localized: "This file may change your browser or computer settings without your permission.")
        case .insecureBlocked:
            String(localized: "The engine blocked this insecure download.")
        case .policyBlocked:
            String(
                localized:
                    "The engine blocked this download because of its safety or organization policy verdict.")
        }
    }
}
