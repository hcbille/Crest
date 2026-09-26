import SwiftUI

struct BrowserSourceImportChrome: View {
    let application: ImportSource?

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
                    .opacity(0.45)
                Spacer()
                Label(
                    application?.title ?? "Browser",
                    systemImage: application?.symbol ?? "globe"
                )
                .labelStyle(.iconOnly)
                .font(.headline)
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                Text("Search or enter website")
                    .lineLimit(1)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(.thinMaterial, in: .rect(cornerRadius: 9, style: .continuous))
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
    }
}
