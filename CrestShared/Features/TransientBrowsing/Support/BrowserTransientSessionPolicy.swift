import Foundation

/// Describes whether a transient request may retain a live page. A usable
/// request carries the Space the page hosts open its page in, as the session
/// copy holds it; TRANSITIONAL until Lane 2's page hosts take the read
/// model's.
enum BrowserTransientLeaseDisposition: Equatable, Sendable {
    case notPresented
    case sourceMissing
    case sourceLocked
    case usable(BrowserSpace)
}

/// Native presentation and authentication observations for transient pages.
enum BrowserTransientSessionPolicy {
    @MainActor
    static func disposition(
        isPresentingRequest: Bool,
        space: BrowserSpace?,
        isLocked: @MainActor (BrowserSpace) -> Bool
    ) -> BrowserTransientLeaseDisposition {
        guard isPresentingRequest else { return .notPresented }
        guard let space else { return .sourceMissing }
        guard !isLocked(space) else { return .sourceLocked }
        return .usable(space)
    }

    /// The Spaces of `browser`'s workspace a transient page may move to or
    /// unlock: none being deleted, and none locked but the request's own.
    @MainActor
    static func availableSpaces(
        in browser: BrowserStore,
        requestSpaceID: SpaceID,
        isLocked: @MainActor (SpaceModel) -> Bool
    ) -> [SpaceModel] {
        BrowserSidebarAccessPolicy.availableSpaces(in: browser).filter {
            $0.id == requestSpaceID || !isLocked($0)
        }
    }

    /// A reusable lease must still match the request’s runtime assignment.
    static func reusesLease(
        leaseAssignment: BrowserSpaceRuntimeAssignment,
        requestAssignment: BrowserSpaceRuntimeAssignment,
        leaseCanBeReused: Bool
    ) -> Bool {
        leaseAssignment == requestAssignment && leaseCanBeReused
    }

}
