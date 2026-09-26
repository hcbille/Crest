import Foundation
import os

/// The platform's side of this device's link preferences.
///
/// The core owns them: the device store keeps them, the core applies every
/// edit and its rules, forgets a deleted Space in them, and routes a link
/// another app hands a window. This store reads them from the read model and
/// sends the person's changes as intents.
@MainActor
final class BrowserLinkPreferenceStore {
    // MARK: - Static Variables

    private static let logger = Logger(subsystem: "com.pauldavis.crest", category: "Links")

    /// TRANSITIONAL until pages ask the core how a clicked link opens: the
    /// store the launch shares with pages that read a preference directly. It
    /// runs over a memory-only core of its own until the launch shares the
    /// store over its core.
    private(set) static var shared = BrowserLinkPreferenceStore()

    // MARK: - Variables

    private let core: CrestCore

    /// The preferences as the core last published them.
    var preferences: LinkPreferences {
        guard let preferences = core.state.linkPreferences else {
            preconditionFailure("The core publishes the link preferences when the store adopts them.")
        }
        return preferences
    }

    // MARK: - Initializers

    /// A store over `core`. It carries the preferences an installed release
    /// kept under `crest.link-preferences.v1`, `legacyPreferences`, into the
    /// core's device store once; the core publishes them either way.
    init(core: CrestCore, legacyPreferences: Data? = nil) {
        self.core = core
        do {
            try core.send(AdoptLinkPreferences(preferences: legacyPreferences))
        } catch {
            preconditionFailure("The core refused to adopt the link preferences: \(error). Rebuild the core.")
        }
    }

    /// A store over a memory-only core of its own, as previews and tests
    /// use, which keeps nothing.
    convenience init() {
        self.init(core: CrestCore())
    }

    // MARK: - Actions - Sharing

    /// Shares `store` with the pages that read a preference directly.
    static func share(_ store: BrowserLinkPreferenceStore) {
        shared = store
    }

    // MARK: - Actions - Changes

    func setBehavior(_ behavior: LinkBehavior, isOn: Bool) {
        send(SetLinkBehavior(behavior: behavior, isOn: isOn))
    }

    /// Where a link from another app opens when no route takes it; `spaceID`
    /// names the Space a destination that asks for one opens, and nil keeps
    /// the one chosen before.
    func chooseExternalDestination(_ destination: ExternalLinkDestination, spaceID: SpaceID? = nil) {
        send(ChooseExternalLinkDestination(destination: destination, spaceID: spaceID))
    }

    func choosePeekModifier(_ modifier: LinkPeekModifier) {
        send(ChoosePeekModifier(modifier: modifier))
    }

    func chooseArchivePolicy(_ policy: QuickWindowArchivePolicy) {
        send(ChooseQuickWindowArchivePolicy(policy: policy))
    }

    func addRoute(destinationSpaceID: SpaceID) {
        send(AddLinkRoute(routeID: UUID(), destinationSpaceID: destinationSpaceID))
    }

    func updateRoute(_ id: UUID, field: BrowserLinkRouteFieldUpdate) {
        send(field.edit(of: id))
    }

    func removeRoute(_ id: UUID) {
        send(RemoveLinkRoute(routeID: id))
    }

    func moveRoute(_ id: UUID, by offset: Int) {
        send(MoveLinkRoute(routeID: id, offset: offset))
    }

    /// Sends an edit; one the core refuses leaves the preferences as they were.
    private func send(_ intent: some LinkIntent) {
        do {
            try core.send(intent)
        } catch {
            Self.logger.error(
                "The core refused \(String(describing: type(of: intent)), privacy: .public): \(String(describing: error), privacy: .public)"
            )
        }
    }
}
