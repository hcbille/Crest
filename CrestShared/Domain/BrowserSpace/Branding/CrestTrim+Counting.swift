import Foundation

extension CrestTrim {
    /// Whether the trim is made of repeated elements, and so reads
    /// `SpaceCrest.trimDetail`.
    var isCounted: Bool {
        switch self {
        case .sunburst, .beaded: true
        default: false
        }
    }
}
