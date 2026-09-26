namespace CrestCore.Contracts;

/// Setup as it stands on this device, over the workspace `WorkspaceId`: how
/// the person arrived, the step they see and where Back and Next lead from it,
/// what setup is doing, the browsers offered and chosen, the import queue and
/// the browser it is on, the review of that browser, why setup could not go
/// on, what it did last, and whether finishing opens the Getting Started
/// guide. `OpensCrestFromWelcome` is whether the welcome offers to open Crest
/// rather than set it up, as it does once setup is done.
public sealed record SetupFlowState(Guid WorkspaceId, SetupEntry Entry, SetupStep Step, SetupStep? BackStep, SetupStep? NextStep,
    SetupPhase Phase, IReadOnlyList<ImportSource> Offered, IReadOnlyList<ImportSource> Selected, SetupImportQueue? Queue,
    ImportSource? Source, SetupImportReview? Review, SetupFailure? Failure, SetupSummary? Summary, bool OpensGuide,
    bool OpensCrestFromWelcome);
