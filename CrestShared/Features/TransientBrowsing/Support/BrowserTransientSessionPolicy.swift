import Foundation

/// Describes whether a transient request may retain a live page. A usable
/// request carries the Space of the read model its page opens in.
@MainActor
enum BrowserTransientLeaseDisposition: Equatable {
    case notPresented
    case sourceMissing
    case sourceLocked
    case usable(SpaceModel)

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.notPresented, .notPresented), (.sourceMissing, .sourceMissing), (.sourceLocked, .sourceLocked): true
        case (.usable(let left), .usable(let right)): left === right
        default: false
        }
    }
}

/// Native presentation and authentication observations for transient pages.
enum BrowserTransientSessionPolicy {
    @MainActor
    static func disposition(
        isPresentingRequest: Bool,
        space: SpaceModel?,
        isLocked: @MainActor (SpaceModel) -> Bool
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
        requestSpaceID: UUID,
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
