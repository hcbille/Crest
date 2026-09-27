import SwiftUI

struct BrowserSourceImportPreview: View {
    let application: ImportSource?
    let review: BrowserImportSpaceReview
    let overflowTabIDs: Set<UUID>
    let duplicateTabIDs: Set<UUID>
    let duplicateDestinationName: String?
    let setIncluded: (UUID, Bool) -> Void
    let setSectionIncluded: (Set<UUID>, Bool) -> Void
    let setPlacement: (UUID, TabPlacement) -> Void

    var body: some View {
        BrowserImportSidebarFrame(branding: review.sourceSpace.settings.look) {
            BrowserSourceImportContent(
                application: application,
                review: review,
                sections: BrowserSourceImportPreviewSections(review: review),
                overflowTabIDs: overflowTabIDs,
                duplicateTabIDs: duplicateTabIDs,
                duplicateDestinationName: duplicateDestinationName,
                setIncluded: setIncluded,
                setSectionIncluded: setSectionIncluded,
                setPlacement: setPlacement
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(application?.title ?? "Source browser") \(review.sourceSpace.settings.name) sidebar before import"
        )
    }
}
