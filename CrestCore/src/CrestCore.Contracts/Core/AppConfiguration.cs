namespace CrestCore.Contracts;

/// How the host creates the core. `StorageDirectory` is where the core keeps
/// `session.sqlite`; null keeps everything in memory, as private browsing,
/// temporary workspaces, tests and previews need. `Platform` is the device
/// class the core answers for, whose defaults its rules apply, such as each
/// shortcut's default keys. `ImportNames` holds the names an import gives the
/// Spaces it names itself, in the person's language; a source missing there
/// names them in English.
public sealed record AppConfiguration(string? StorageDirectory, DevicePlatform Platform,
    IReadOnlyList<ImportSpaceNames>? ImportNames = null) : Configuration;
