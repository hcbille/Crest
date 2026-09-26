namespace CrestCore.Contracts;

/// Goes on from choosing browsers: with none chosen, to setting up Spaces by
/// hand; otherwise to reading the next chosen browser, which the platform
/// then reads and hands back in `ReviewImport`.
public sealed record ContinueImport() : SetupFlowIntent;
