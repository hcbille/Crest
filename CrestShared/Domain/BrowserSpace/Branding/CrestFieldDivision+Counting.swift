import Foundation

extension CrestFieldDivision {
    /// Whether the division repeats, and so reads `SpaceCrest.divisionCount`.
    var isCounted: Bool {
        switch self {
        case .gyronny, .barry, .paly, .checky: true
        default: false
        }
    }
}
