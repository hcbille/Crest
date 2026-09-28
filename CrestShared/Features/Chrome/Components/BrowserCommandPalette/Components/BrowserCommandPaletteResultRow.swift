import SwiftUI

struct BrowserCommandPaletteResultRow: View {
    let model: BrowserCommandPaletteModel
    let item: BrowserCommandPaletteItem

    var body: some View {
        Button {
            model.activate(item.row)
        } label: {
            HStack(spacing: BrowserCommandPaletteMetrics.rowSpacing) {
                BrowserCommandPaletteRowIcon(model: model, row: item.row)

                VStack(
                    alignment: .leading,
                    spacing: BrowserCommandPaletteMetrics.rowTextSpacing
                ) {
                    Text(verbatim: item.row.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    if !item.row.subtitle.isEmpty {
                        Text(verbatim: item.row.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: BrowserCommandPaletteMetrics.rowSpacing)

                BrowserCommandPaletteRowTrailing(model: model, row: item.row)

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(
            BrowserCommandPaletteRowButtonStyle(
                isSelected: model.selectedResultIndex == item.index
            )
        )
        .accessibilityValue(model.engineBadge(for: item.row).map { Text($0.pageDescription) } ?? Text(verbatim: ""))
        .accessibilityIdentifier("command-palette-result-\(item.index)")
        .browserCommandPaletteHoverSelection(model: model, index: item.index)
    }
}

#if DEBUG
    #Preview("Tab and command results") {
        let model = BrowserCommandPalettePreviewFixture.model(query: "swift")
        VStack(spacing: 4) {
            BrowserCommandPaletteResultRow(model: model, item: BrowserCommandPalettePreviewFixture.tabItem)
            BrowserCommandPaletteResultRow(model: model, item: BrowserCommandPalettePreviewFixture.commandItem)
        }.padding().frame(width: 600)
    }
#endif
