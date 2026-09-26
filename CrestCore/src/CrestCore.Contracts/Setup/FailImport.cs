namespace CrestCore.Contracts;

/// Reading or importing `Source` failed for `Reason`, in the words of what
/// refused it, `Detail`, when something did. Setup goes back to the step and
/// phase that can try again.
public sealed record FailImport(ImportSource Source, SetupFailureReason Reason, string? Detail) : SetupFlowIntent;
