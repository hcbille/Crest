import Foundation

/// One stateless core policy call. Raw values are the core's spellings in
/// `PolicyOperation.cs`.
enum BrowserPolicyOperation: String, Codable, Sendable {
    case residencyReleaseLimit = "residency.release_limit"
    case residencyReleasePlan = "residency.release_plan"
}
