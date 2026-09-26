import SwiftUI

struct BrowserDataPortabilityFootnotes: View {
    var body: some View {
        Text(
            "Exports Spaces, folders, saved and current tabs, Archive, history, and browsing preferences. Passwords, cookies, website storage, permissions, downloads, favicons, and extensions are never included."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("browser-data-exclusions")
    }
}
