import SwiftUI

struct BrowserCommandPaletteRowTrailing: View {
    let model: BrowserCommandPaletteModel
    let row: PaletteRow

    @ViewBuilder
    var body: some View {
        if let command = row.command,
            let chord = model.commands?.shortcut(for: command)
        {
            Text(verbatim: chord.displayString)
                .font(.caption.weight(.medium).monospaced())
                .foregroundStyle(.secondary)
                .padding(
                    .horizontal,
                    BrowserCommandPaletteMetrics.shortcutHorizontalPadding
                )
                .frame(minHeight: BrowserCommandPaletteMetrics.shortcutMinimumHeight)
                .background(
                    .primary.opacity(
                        BrowserCommandPaletteMetrics.shortcutBackgroundOpacity
                    ),
                    in: .rect(
                        cornerRadius: BrowserCommandPaletteMetrics.shortcutCornerRadius
                    )
                )
                .accessibilityLabel(Text(verbatim: chord.spokenDescription))
        } else if let action = row.kind.action {
            Text(action)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#if DEBUG
    #Preview("Command shortcut") {
        BrowserCommandPaletteRowTrailing(
            model: BrowserCommandPalettePreviewFixture.model(query: "swift"),
            row: BrowserCommandPalettePreviewFixture.commandRow
        ).padding()
    }
#endif
