namespace CrestCore.Contracts;

/// The server's fields of one uploaded record, as the transport archived
/// them, and the record schema the server copy carries, which the archive
/// leaves out. The transport uploads over them, so a save targets the
/// server's version.
public sealed record CloudRecordFields(string RecordName, byte[] Fields, int? SchemaVersion);
