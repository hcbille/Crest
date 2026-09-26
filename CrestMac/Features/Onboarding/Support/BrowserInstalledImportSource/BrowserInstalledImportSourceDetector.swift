import AppKit

@MainActor
enum BrowserInstalledImportSourceDetector {
    /// Each browser Crest imports from that is installed, with what the core
    /// found in its data folder.
    static func installedSources(
        workspace: NSWorkspace = .shared
    ) -> [BrowserInstalledImportSource] {
        ImportSource.all.compactMap { application in
            guard
                let url = workspace.urlForApplication(
                    withBundleIdentifier: application.bundleIdentifier
                )
            else { return nil }
            let icon = workspace.icon(forFile: url.path)
            icon.size = NSSize(width: 64, height: 64)
            return BrowserInstalledImportSource(
                application: application,
                applicationURL: url,
                detectedPayload: BrowserDetectedImportPayload(
                    application: application,
                    data: application.importData(in: application.defaultDataDirectory)
                ),
                icon: icon
            )
        }
    }
}
