import SwiftUI

struct BrowserDataPortabilityContent: View {
    let model: BrowserDataPortabilityModel
    let showsMacOSImportRequirement: Bool

    var body: some View {
        Section("Import & Export", systemImage: "square.and.arrow.up.on.square") {
            if showsMacOSImportRequirement {
                BrowserDataPortabilityMacRequirement()
            }
            BrowserDataPortabilityExportControls(model: model)
            BrowserDataPortabilityProgressStatus(model: model)
            BrowserDataPortabilityFootnotes()
        }
    }
}
