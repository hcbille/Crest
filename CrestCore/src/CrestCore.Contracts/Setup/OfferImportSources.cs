namespace CrestCore.Contracts;

/// The browsers the platform found installed, in the order it lists them,
/// which is the order setup imports from them.
public sealed record OfferImportSources(IReadOnlyList<ImportSource> Installed) : SetupFlowIntent;
