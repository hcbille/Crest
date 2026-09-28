import Foundation
import os

/// A category of Crest's unified log. The application layer writes through
/// it, so the stores that report a core's refusal name where the message goes
/// without depending on the logging framework. A message is written public,
/// whole, as it reads.
struct DiagnosticLog: Sendable {
    // MARK: - Static Variables

    static let links = DiagnosticLog(category: "Links")
    static let popups = DiagnosticLog(category: "Popups")
    static let shortcuts = DiagnosticLog(category: "Shortcuts")
    static let sitePermissions = DiagnosticLog(category: "SitePermissions")
    static let windows = DiagnosticLog(category: "Windows")

    // MARK: - Variables

    private let logger: Logger

    // MARK: - Initializers

    private init(category: String) {
        logger = Logger(subsystem: "com.pauldavis.crest", category: category)
    }

    // MARK: - Actions - Describing

    /// How a message names `error`: a rejection by its rule alone, because
    /// what it carries can name an address or a site the log must not keep,
    /// and any other error as it describes itself.
    static func describe(_ error: any Error) -> String {
        guard let rejection = error as? Rejection else { return String(describing: error) }
        return Mirror(reflecting: rejection).children.first?.label ?? String(describing: rejection)
    }

    // MARK: - Actions - Writing

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    func notice(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }
}
