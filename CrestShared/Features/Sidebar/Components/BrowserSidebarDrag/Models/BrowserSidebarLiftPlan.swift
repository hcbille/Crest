import Foundation

/// What one lift carries from its start to its drop: what it lifts, as the
/// core reads a sidebar selection, and where the core would let it land. The
/// lists, Spaces and cards it may reach are asked once as the lift begins;
/// whether a drop lands in a list or on a Space is asked the first time the
/// lift reaches it, so a lift pays only for the targets it visits. A drop can
/// still be refused when it lands, since the session can change while the lift
/// is held; its commit decides.
struct BrowserSidebarLiftPlan: Equatable, Sendable {
    // MARK: - Variables

    let selection: TabSelection
    /// Every list, Space and open tab the lift may reach, and whether it may
    /// join the cards on show, or nil when the core could not answer.
    let targets: DropTargetList?
    /// The core's answer for each list or Space the lift reached, or nil for a
    /// plan that never asks, which lets every listed drop land.
    private let refusals: BrowserSidebarDropRefusals?

    // MARK: - Initializers

    init(selection: TabSelection, targets: DropTargetList?, refusals: BrowserSidebarDropRefusals? = nil) {
        self.selection = selection
        self.targets = targets
        self.refusals = refusals
    }

    // MARK: - Actions - Targets

    /// What the core says of dropping the lift on `target`: whether it may
    /// land there, the rule that refuses it, or that the core offers no such
    /// target for this lift at all.
    @MainActor
    func verdict(on target: BrowserSidebarReorderTarget) -> BrowserSidebarDropVerdict {
        guard let targets else { return .unavailable }
        if let refusal = targets.refusal { return .refused(refusal) }
        switch target.kind {
        case .insert(let section, _, _):
            let list: ListDropTarget?
            switch section {
            case .tabs(let placement, let folderID):
                list = targets.lists.first { $0.section == placement && $0.folderID == folderID }
            case .folders(let parentID):
                list = targets.lists.first { $0.folderID == parentID && (parentID != nil || $0.section == .saved) }
            }
            return verdict(onList: list)
        case .intoFolder(let folderID):
            return verdict(onList: targets.lists.first { $0.folderID == folderID })
        case .space(let assignment):
            guard targets.spaceIDs.contains(assignment.spaceID) else { return .unavailable }
            guard let refusals else { return .allowed }
            return BrowserSidebarDropVerdict(.some(refusals.refusal(onSpace: assignment.spaceID, selection: selection)))
        case .splitInsert:
            return BrowserSidebarDropVerdict(targets.split.map { $0.refusal })
        case .createCurrentFolder(let tabID):
            return targets.folderAroundTabIDs.contains(tabID) ? .allowed : .unavailable
        }
    }

    @MainActor
    private func verdict(onList list: ListDropTarget?) -> BrowserSidebarDropVerdict {
        guard let list else { return .unavailable }
        guard let refusals else { return .allowed }
        return BrowserSidebarDropVerdict(.some(refusals.refusal(onList: list, selection: selection)))
    }

    // MARK: - Actions - Equality

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selection == rhs.selection && lhs.targets == rhs.targets
    }
}

/// The core's answers for the drops one lift reached: each list or Space is
/// asked once, the first time the lift is over it, and kept for the lift.
@MainActor
final class BrowserSidebarDropRefusals {
    // MARK: - Types

    private enum Target: Hashable {
        case list(TabPlacement, UUID?)
        case space(UUID)
    }

    // MARK: - Variables

    private weak var browser: BrowserStore?
    private let spaceID: UUID
    private var answers: [Target: Rejection?] = [:]

    // MARK: - Initializers

    /// Answers for a lift in the sidebar of `browser`'s window, over `spaceID`.
    init(browser: BrowserStore, spaceID: UUID) {
        self.browser = browser
        self.spaceID = spaceID
    }

    // MARK: - Actions - Asking

    func refusal(onList list: ListDropTarget, selection: TabSelection) -> Rejection? {
        answer(.list(list.section, list.folderID)) { browser in
            DropIntoList(
                workspaceID: browser.family.workspaceID, windowID: browser.windowID, spaceID: spaceID,
                selection: selection, section: list.section, folderID: list.folderID, beforeTabID: nil,
                beforeFolderID: nil)
        }
    }

    func refusal(onSpace destinationID: UUID, selection: TabSelection) -> Rejection? {
        answer(.space(destinationID)) { browser in
            DropOnSpace(
                workspaceID: browser.family.workspaceID, windowID: browser.windowID, spaceID: spaceID,
                selection: selection, destinationSpaceID: destinationID, follows: false)
        }
    }

    private func answer(_ target: Target, drop: (BrowserStore) -> some Intent) -> Rejection? {
        if let known = answers[target] { return known }
        guard let browser else { return nil }
        let refusal = browser.family.refusal(of: drop(browser), from: browser)
        answers[target] = refusal
        return refusal
    }
}

/// What the core says of one drop: it may land, a rule refuses it, or the
/// core offers no such target for the lift.
enum BrowserSidebarDropVerdict: Equatable, Sendable {
    case allowed
    case refused(Rejection)
    case unavailable

    /// A target the core listed, refused by `refusal` or allowed; a target it
    /// did not list, unavailable.
    init(_ listed: Rejection??) {
        switch listed {
        case .none: self = .unavailable
        case .some(.none): self = .allowed
        case .some(.some(let refusal)): self = .refused(refusal)
        }
    }
}

extension BrowserSidebarLiftPlan {
    /// Whether the core offers a drop on the zone for this lift at all, refused
    /// or not. A lift the core refuses outright is offered everywhere, so the
    /// preview can say why wherever it goes. The cards on show are the one
    /// exception: a refused join opens no placeholder among them, since the
    /// columns would make room for a card that never arrives.
    func offers(_ zone: BrowserSidebarReorderZone.Target) -> Bool {
        guard let targets, targets.refusal == nil else { return true }
        switch zone {
        case .section(.tabs(let placement, let folderID)):
            return targets.lists.contains { $0.section == placement && $0.folderID == folderID }
        case .section(.folders(let parentID)):
            return targets.lists.contains { $0.folderID == parentID }
        case .folder(let folderID):
            return targets.lists.contains { $0.folderID == folderID }
        case .currentTab(let tabID):
            return targets.folderAroundTabIDs.contains(tabID)
        case .space(let assignment):
            return targets.spaceIDs.contains(assignment.spaceID)
        case .splitContent:
            return targets.split.map { $0.refusal == nil } ?? false
        }
    }
}
