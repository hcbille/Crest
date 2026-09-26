namespace CrestCore.Contracts;

/// What setup did last: the tabs, passwords and Spaces an import brought,
/// or the Spaces a manual setup created and the tabs it added.
public sealed record SetupSummary(bool IsImport, int TabCount, int PasswordCount, int SpaceCount);
