namespace CrestCore.Contracts;

/// The Spaces each of `Passwords` goes to once the review setup holds for
/// `WorkspaceId` is imported: the destination of each reviewed Space that
/// brings its passwords and that the password belongs with. A Space that is
/// gone or locked takes none. Throws `Rejected` with `NoSetup` when setup
/// holds no review for the workspace.
[MessageLimit(64 * 1024 * 1024)]
public sealed record ImportPasswordDestinations(Guid WorkspaceId, IReadOnlyList<ImportPasswordSource> Passwords)
    : Query<ImportPasswordRoutes>;
