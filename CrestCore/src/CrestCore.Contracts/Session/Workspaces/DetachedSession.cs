namespace CrestCore.Contracts;

/// The session `Seed` opens as, repaired as a stored session is when it loads
/// and resolved, for a view that shows Spaces no workspace holds: a preview,
/// or a draft before it is saved. Nothing opens, so no change of it is ever
/// published. It reads no state, so a host may ask it without an app.
public sealed record DetachedSession(SessionState Seed) : Query<SessionState>;
