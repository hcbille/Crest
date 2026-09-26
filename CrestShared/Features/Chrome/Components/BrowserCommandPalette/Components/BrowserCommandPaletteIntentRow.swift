import SwiftUI

struct BrowserCommandPaletteIntentRow: View {
    let model: BrowserCommandPaletteModel
    let item: BrowserCommandPaletteItem

    var body: some View {
        Button {
            model.activate(item.row)
        } label: {
            HStack(spacing: BrowserCommandPaletteMetrics.rowSpacing) {
                Group {
                    if let provider = model.searchProvider(for: item.row) {
                        BrowserSearchProviderIcon(
                            provider: provider,
                            profileID: model.space?.profileID,
                            size: BrowserCommandPaletteMetrics.intentSymbolPointSize
                        )
                    } else {
                        Image(systemName: item.row.symbol)
                            .font(
                                .system(
                                    size: BrowserCommandPaletteMetrics.intentSymbolPointSize,
                                    weight: .semibold
                                )
                            )
                    }
                }
                .frame(
                    width: BrowserCommandPaletteMetrics.rowIconContainerSize,
                    height: BrowserCommandPaletteMetrics.rowIconContainerSize
                )
                .background(
                    .primary.opacity(
                        BrowserCommandPaletteMetrics.rowIconBackgroundOpacity
                    ),
                    in: .rect(
                        cornerRadius: BrowserCommandPaletteMetrics.rowIconCornerRadius
                    )
                )
                .accessibilityHidden(true)

                VStack(
                    alignment: .leading,
                    spacing: BrowserCommandPaletteMetrics.rowTextSpacing
                ) {
                    Text(verbatim: item.row.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text(verbatim: item.row.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: BrowserCommandPaletteMetrics.rowSpacing)

                Image(systemName: "arrow.turn.down.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(
            BrowserCommandPaletteRowButtonStyle(
                isSelected: model.selectedResultIndex == item.index
            )
        )
        .accessibilityLabel(Text(verbatim: item.row.title))
        .accessibilityValue(Text(verbatim: item.row.subtitle))
        .accessibilityIdentifier("command-palette-primary-action")
        .browserCommandPaletteHoverSelection(model: model, index: item.index)
    }
}

#if DEBUG
    #Preview("Search intent") {
        BrowserCommandPaletteIntentRow(
            model: BrowserCommandPalettePreviewFixture.model(query: "swift"),
            item: BrowserCommandPalettePreviewFixture.intentItem
        )
        .padding().frame(width: 600)
    }
#endif
