namespace CrestCore.Contracts;

/// Every engine this device registered, in `EngineKind.All` order.
public sealed record EngineRoster(IReadOnlyList<EngineState> Engines) {
    #region Variables

    /// What the device offers anywhere a person can find a feature, such as a
    /// menu, the launcher or a settings page: every capability some registered
    /// engine supports, in `EngineCapability.All` order. Every capability,
    /// until an engine registers. Whether a page can use one is its own
    /// engine's answer.
    [Resolved]
    public IReadOnlyList<EngineCapability> Offered => Engines.Count == 0
        ? EngineCapability.All
        : [.. EngineCapability.All.Where(capability => Engines.Any(engine => engine.Capabilities.Contains(capability)))];

    #endregion
}
