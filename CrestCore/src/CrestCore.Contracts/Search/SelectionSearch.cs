namespace CrestCore.Contracts;

/// The search for text a person selected on a page of `SpaceId`, with the
/// Space's search engine.
public sealed record SelectionSearch(Guid WorkspaceId, Guid SpaceId, string Text) : Query<SelectionSearchAnswer>;
