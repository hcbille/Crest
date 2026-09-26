namespace CrestCore.Contracts;

/// `Source`'s `SpaceName` and `NumberedSpaceName` in the person's language, as
/// the platform resolved them, so a Space an import names is stored as the
/// person reads it. `NumberedSpaceName` keeps its `%lld`.
public sealed record ImportSpaceNames(ImportSource Source, string SpaceName, string NumberedSpaceName);
