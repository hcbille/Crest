import Foundation

/// Quick Window rules owned by the portable core.
extension BrowserCorePolicy {
    // MARK: - Types

    private struct QuickWindowDismissalRequest: Encodable {
        let wasArchived: Bool
        let wasPromoted: Bool
        let hasPage: Bool
    }

    private struct QuickWindowDismissalAnswer: Decodable {
        @BrowserCoreOptional var archives: Bool?
    }

    private struct RetargetRequest: Encodable {
        struct Placement: Encodable {
            let url: String
            let spaceID: String
            let profileID: String

            init(_ url: URL, _ assignment: BrowserSpaceRuntimeAssignment) {
                self.url = url.absoluteString
                spaceID = assignment.spaceID.coreIdentifier
                profileID = assignment.profileID.coreIdentifier
            }
        }

        let current: Placement
        let next: Placement
        @BrowserCoreNullable var pageURL: String?
    }

    private struct RetargetAnswer: Decodable {
        let revises: Bool
        let remembersSpace: Bool
    }

    // MARK: - Actions - Quick Windows

    /// Whether dismissing a Quick Window files its page in the archive. A core
    /// that cannot answer archives nothing: no durable record is written
    /// without the core's rule, and the archive command would refuse anyway.
    static func quickWindowArchivesOnDismissal(wasArchived: Bool, wasPromoted: Bool, hasPage: Bool) -> Bool {
        let request = QuickWindowDismissalRequest(wasArchived: wasArchived, wasPromoted: wasPromoted, hasPage: hasPage)
        return evaluate(.quickWindowDismissal, request, answer: QuickWindowDismissalAnswer.self)?.archives ?? false
    }

    /// Whether moving a Quick Window to `url` in `assignment` revises its
    /// request, and whether the move remembers the Space for the page's site.
    /// `pageURL` is nil for an empty lookup. A core that cannot answer leaves
    /// the request as it was and remembers nothing.
    static func quickWindowRetarget(
        _ request: BrowserQuickWindowRequest, to url: URL,
        assignment: BrowserSpaceRuntimeAssignment, pageURL: URL?
    ) -> (revises: Bool, remembersSpace: Bool) {
        let retarget = RetargetRequest(
            current: RetargetRequest.Placement(request.url, request.assignment),
            next: RetargetRequest.Placement(url, assignment), pageURL: pageURL?.absoluteString)
        guard let answer = evaluate(.quickWindowRetarget, retarget, answer: RetargetAnswer.self) else {
            return (false, false)
        }
        return (answer.revises, answer.remembersSpace)
    }
}
