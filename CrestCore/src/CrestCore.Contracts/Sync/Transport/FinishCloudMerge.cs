namespace CrestCore.Contracts;

/// The merge `MergeId` ended, having taken its records when `Succeeded`. A
/// failed merge leaves a full pull required; a full snapshot taken with no
/// merge failing meanwhile recovers every earlier one. The full pull stays
/// required while another merge is under way. A merge this device never
/// began is `UnknownCloudMerge`.
public sealed record FinishCloudMerge(long MergeId, bool Succeeded, bool FullSnapshot) : CloudTransportIntent;
