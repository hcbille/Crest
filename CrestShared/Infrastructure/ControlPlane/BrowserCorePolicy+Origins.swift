import Foundation

/// External scheme, link and local-file rules answered by the portable core.
/// URLs cross as the facts Foundation's parser reports, so the core judges the
/// same parse the engine loads. Every answer fails closed: a link or document
/// that cannot be evaluated is refused, and a scheme is blocked.
extension BrowserCorePolicy {
    // MARK: - Actions - Origins

    /// Whether another application, a drop, a peek, a popup or a menu item may
    /// hand Crest this URL as a web link: HTTP or HTTPS with a host.
    static func acceptsExternalURL(_ url: URL) -> Bool {
        let question = ExternalWebLink(scheme: nonEmpty(url.scheme), host: nonEmpty(url.host(percentEncoded: false)))
        return (try? CrestCore.answer(question))?.accepted ?? false
    }

    /// Whether Crest opens this URL as a local document. Only document-open
    /// routes ask; a web link never reaches a local path through this.
    static func acceptsLocalDocument(_ url: URL) -> Bool {
        let facts = LocalDocumentFacts(
            isFile: url.isFileURL, hasUser: url.user() != nil, hasPath: !url.path().isEmpty,
            host: nonEmpty(url.host(percentEncoded: false)))
        return (try? CrestCore.answer(ExternalLocalDocument(facts: facts)))?.accepted ?? false
    }

    /// Which engine, if any, owns a navigation once its scheme is known. Only
    /// a load Crest itself initiated may keep `file:`.
    static func externalSchemeDisposition(for url: URL?, isAppInitiated: Bool = false)
        -> ExternalSchemeDisposition
    {
        let question = SchemeHandling(scheme: nonEmpty(url?.scheme), appInitiated: isAppInitiated)
        return (try? CrestCore.answer(question))?.disposition ?? .blocked
    }

    /// An empty component crosses as `nil`, as a missing one does.
    static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
