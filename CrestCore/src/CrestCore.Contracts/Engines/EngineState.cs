namespace CrestCore.Contracts;

/// One engine this device registered, as the read model shows it: the
/// capabilities its binding supports, in `EngineCapability.All` order, and
/// whether new pages open on it. A page's own engine answers what the page
/// can do.
public sealed record EngineState(EngineKind Kind, IReadOnlyList<EngineCapability> Capabilities, bool IsDefault);
