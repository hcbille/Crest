namespace CrestCore.Contracts;

/// A manual setup in progress over the workspace `WorkspaceId`: its Spaces as
/// the person is setting them up, each an existing Space or a new one, in the
/// order the workspace takes when `OrderWasEdited`. The device holds one setup
/// at a time and follows Spaces changed elsewhere while it waits: an existing
/// Space deleted meanwhile leaves it, and one created meanwhile joins at the
/// end. `ApplyManualSetup` applies it.
public sealed record SetupDraft(Guid WorkspaceId, IReadOnlyList<SetupDraftSpace> Spaces, bool OrderWasEdited);
