import Foundation

struct BrowserImportQueue: Equatable, Sendable {
    private(set) var applications: [ImportSource]
    private(set) var currentIndex: Int

    init(
        applications: [ImportSource],
        currentIndex: Int = 0
    ) {
        self.applications = applications
        self.currentIndex = min(max(0, currentIndex), applications.count)
    }

    init(
        selected: Set<ImportSource>,
        availableOrder: [ImportSource]
    ) {
        self.init(applications: availableOrder.filter(selected.contains))
    }

    var current: ImportSource? {
        applications.indices.contains(currentIndex)
            ? applications[currentIndex]
            : nil
    }

    var count: Int { applications.count }

    var position: Int {
        current == nil ? count : currentIndex + 1
    }

    var isComplete: Bool { current == nil }

    var remaining: ArraySlice<ImportSource> {
        applications.dropFirst(currentIndex)
    }

    var hasMoreAfterCurrent: Bool {
        currentIndex + 1 < applications.count
    }

    var progressLabel: String? {
        guard count > 1, current != nil else { return nil }
        return "Browser \(position) of \(count)"
    }

    @discardableResult
    mutating func advance() -> Bool {
        currentIndex = min(currentIndex + 1, applications.count)
        return current != nil
    }
}
