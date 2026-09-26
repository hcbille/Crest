namespace CrestCore.Contracts;

/// No merge of downloaded records under way on this device is named `MergeId`.
public sealed record UnknownCloudMerge(long MergeId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Crest lost track of an iCloud download it was applying.";

    #endregion
}
