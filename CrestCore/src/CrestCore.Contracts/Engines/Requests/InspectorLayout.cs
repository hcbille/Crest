namespace CrestCore.Contracts;

/// The areas of a card the docked inspector and its page take, or neither when
/// no inspector is docked. A page area with no size means the inspector
/// covers the page on purpose.
public sealed record InspectorLayout(PageArea? Inspector, PageArea? Page);
