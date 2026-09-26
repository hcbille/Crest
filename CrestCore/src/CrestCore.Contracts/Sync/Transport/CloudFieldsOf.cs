namespace CrestCore.Contracts;

/// The server fields the device store keeps of `RecordNames`.
public sealed record CloudFieldsOf(IReadOnlyList<string> RecordNames) : Query<CloudRecordFieldList>;
