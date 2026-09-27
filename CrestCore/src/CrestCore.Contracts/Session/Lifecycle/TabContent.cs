namespace CrestCore.Contracts;

/// What a new tab shows: the page at `Address`, the native view `View`, or,
/// with neither, the Start Page. `Title` names a page until it loads and
/// reports its own; a page without one is titled by its host. A native view
/// titles and draws its tab itself.
public sealed record TabContent(string? Address, NativeView? View, string? Title);
