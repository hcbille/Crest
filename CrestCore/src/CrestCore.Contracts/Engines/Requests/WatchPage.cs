namespace CrestCore.Contracts;

/// The platform shows the page from now on. False when the engine does not
/// know it. Otherwise the binding presents where the page stands, whether its
/// view is ready or could not be made, and what that view shows, since the
/// platform may come to a page after the engine created it.
public sealed record WatchPage(Guid PageId) : PageRequest<bool>;
