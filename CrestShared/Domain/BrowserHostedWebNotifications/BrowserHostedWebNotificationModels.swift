import Foundation

enum BrowserHostedWebNotificationAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

struct BrowserHostedWebNotificationDelivery: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let origin: SiteOrigin
    let isSilent: Bool
}

enum BrowserHostedWebNotificationEvent: Equatable, Sendable {
    case clicked
}
