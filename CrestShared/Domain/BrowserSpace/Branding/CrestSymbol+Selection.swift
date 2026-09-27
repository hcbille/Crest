import Foundation

extension CrestSymbol {
    // MARK: - Static Variables

    /// The figure a crest draws when it names none it can read.
    static let fallback = CrestSymbol.mountain

    /// Oak remains readable but is not offered because it renders identically
    /// to leaf.
    static let selectable: [CrestSymbol] = allCases.filter { $0 != .oak }
}
