namespace CrestCore.Contracts;

/// Brings the tab `TabId` of the reviewed Space `SourceSpaceId` in
/// `Placement`, and with it the Space.
public sealed record PlaceImportTab(Guid SourceSpaceId, Guid TabId, TabPlacement Placement) : SetupFlowIntent;
