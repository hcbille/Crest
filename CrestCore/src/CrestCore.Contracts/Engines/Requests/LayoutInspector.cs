namespace CrestCore.Contracts;

/// Where the docked inspector and the page it inspects go in a card `Width` by
/// `Height` points: the inspector takes its area and the page is drawn over it
/// at its own. Measured from the card's top left.
public sealed record LayoutInspector(Guid PageId, double Width, double Height) : PageRequest<InspectorLayout>;
