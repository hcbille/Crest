import CoreGraphics
import Foundation

struct BrowserFolderDropLocation: Equatable, Sendable {
    let parentID: UUID?
    let beforeSiblingID: UUID?
}

struct BrowserTabDropLocation: Equatable, Sendable {
    let placement: TabPlacement
    let folderID: UUID?
    let beforeTabID: UUID?
    var destinationAssignment: BrowserSpaceRuntimeAssignment? = nil
}

/// Native input feeds shared movement and release handling.
enum BrowserSidebarReorderLiftPhase {
    enum PreviewOwner {
        case application
    }

    case moved(startLocation: CGPoint, location: CGPoint)
    case released(previewOwner: PreviewOwner)
}
