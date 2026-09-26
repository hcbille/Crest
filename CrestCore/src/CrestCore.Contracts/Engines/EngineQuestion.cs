namespace CrestCore.Contracts;

/// What an engine binding asks the core about one of its pages while the
/// engine waits, such as what a person's click on a link does. The core
/// answers with a `TAnswer` at once, from its state, and changes nothing.
public abstract record EngineQuestion<TAnswer>;
