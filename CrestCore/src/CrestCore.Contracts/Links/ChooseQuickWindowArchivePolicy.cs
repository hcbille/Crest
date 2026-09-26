namespace CrestCore.Contracts;

/// Chooses how long an idle Quick Window lives before it is archived.
public sealed record ChooseQuickWindowArchivePolicy(QuickWindowArchivePolicy Policy) : LinkIntent;
