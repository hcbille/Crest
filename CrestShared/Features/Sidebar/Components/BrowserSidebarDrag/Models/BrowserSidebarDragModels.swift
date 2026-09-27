import CoreGraphics

struct BrowserFolderDropLocation: Equatable, Sendable {
    let parentID: FolderID?
    let beforeSiblingID: FolderID?
}

struct BrowserTabDropLocation: Equatable, Sendable {
    let placement: TabPlacement
    let folderID: FolderID?
    let beforeTabID: TabID?
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
