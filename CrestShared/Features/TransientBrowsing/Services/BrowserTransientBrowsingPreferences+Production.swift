extension BrowserTransientBrowsingPreferences {
    /// The app's preferences, as `core` holds this device's link preferences.
    static func production(core: CrestCore) -> BrowserTransientBrowsingPreferences {
        BrowserTransientBrowsingPreferences(
            archiveLifetime: core.state.linkPreferences?.archivePolicy.lifetime,
            rememberSpace: { spaceID, url in
                _ = try? core.send(RememberQuickWindowSpace(url: url.absoluteString, spaceID: spaceID))
            }
        )
    }
}
