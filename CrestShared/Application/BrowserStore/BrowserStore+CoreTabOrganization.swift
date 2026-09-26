import Foundation

extension BrowserStore {
    /// Moves a tab within its Space, and answers whether it moved. The core
    /// takes a split member out of its split for a section that holds none.
    func moveSessionTab(
        _ id: TabID, in spaceID: SpaceID, to placement: TabPlacement,
        folderID: FolderID? = nil, before anchor: TabID? = nil
    ) -> Bool {
        family.send(
            MoveTab(
                workspaceID: family.workspaceID, spaceID: spaceID, tabID: id, placement: placement,
                folderID: folderID, beforeTabID: anchor, leavesSplit: false),
            from: self)
    }

    /// The core has accepted each copy's identity and visible URL/title. The
    /// adapter now prepares its opaque navigation history before pages mount.
    func prepareAcceptedCopies(_ copies: [TabCopied], from space: BrowserSpace) {
        let tabs = session.space(id: space.id)?.tabs ?? []
        for pair in copies {
            guard let source = space.tabs.first(where: { $0.id == pair.sourceTabID }),
                var copy = tabs.first(where: { $0.id == pair.copyTabID })
            else { continue }
            tabCopying?.prepareTabCopy(from: source, to: &copy, in: space)
        }
    }

    /// Runs an intent the window issued in a Space that copies tabs, and
    /// prepares the pages of the copies it made from their sources as they
    /// were. Answers the copies, or nil when the core refused it.
    /// TRANSITIONAL until the WebKit binding prepares copies from the core:
    /// the engine copies from the sources in the session copy.
    @discardableResult
    func sendCopying(_ intent: some Intent, in spaceID: SpaceID) -> [TabCopied]? {
        guard let space = session.space(id: spaceID), let sent = family.perform(intent, from: self) else { return nil }
        let copies: [TabCopied] = sent.changes.compactMap {
            guard case .tabCopied(let copied) = $0, copied.workspaceID == family.workspaceID else { return nil }
            return copied
        }
        prepareAcceptedCopies(copies, from: space)
        return copies
    }
}
