import Foundation

extension AppConfiguration {
    /// A configuration for the device this process runs on, keeping the
    /// session in `storageDirectory`, or in memory when it is nil. An import
    /// names the Spaces it brings in the person's language.
    init(storageDirectory: String?) {
        self.init(
            storageDirectory: storageDirectory, platform: .current,
            importNames: ImportSource.all.compactMap(ImportSpaceNames.init(resolving:)))
    }
}

extension ImportSpaceNames {
    /// `source`'s Space names in the person's language, or nil for a source
    /// whose Spaces are named after its profiles.
    init?(resolving source: ImportSource) {
        guard let spaceName = source.spaceName, let numberedSpaceName = source.numberedSpaceName else { return nil }
        self.init(
            source: source, spaceName: String(localized: spaceName),
            numberedSpaceName: String(localized: numberedSpaceName))
    }
}
