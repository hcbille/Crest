namespace CrestCore.Contracts;

/// The fields the device store keeps of the records asked for; a record it
/// keeps none of is left out.
public sealed record CloudRecordFieldList(IReadOnlyList<CloudRecordFields> Records);
