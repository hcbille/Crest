namespace CrestCore.Contracts;

/// Where each password goes, in the order they were asked about.
public sealed record ImportPasswordRoutes(IReadOnlyList<ImportPasswordRoute> Routes);
