import Foundation

extension CoreState {
    // MARK: - Actions - Changes

    func apply(_ change: EnginesChanged) {
        engines = change.roster
    }

    // MARK: - Actions - Capabilities

    /// Whether the device offers `capability` anywhere a person can find a
    /// feature, such as a menu or a settings page: the default engine or an
    /// engine a page is open on supports it, or no engine has registered yet.
    /// Whether a page can use it is its own engine's answer.
    func offers(_ capability: EngineCapability) -> Bool {
        engines?.offered.contains(capability) ?? true
    }

    /// Whether the engine new pages open on supports `capability`, which
    /// answers for a window before it shows a page. Every capability, until
    /// an engine registers.
    func defaultEngineSupports(_ capability: EngineCapability) -> Bool {
        guard let engines else { return true }
        return engines.engines.first(where: \.isDefault)?.capabilities.contains(capability) == true
    }
}
