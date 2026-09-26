import SwiftUI

struct BrowserCommandPaletteResultRows: View {
    let model: BrowserCommandPaletteModel
    let items: [BrowserCommandPaletteItem]

    var body: some View {
        ForEach(items) { item in
            if item.row.kind.isPrimary {
                BrowserCommandPaletteIntentRow(model: model, item: item)
                    .id(item.id)
            } else {
                BrowserCommandPaletteResultRow(model: model, item: item)
                    .id(item.id)
            }
        }
    }
}
