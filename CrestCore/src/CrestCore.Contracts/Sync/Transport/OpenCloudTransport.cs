namespace CrestCore.Contracts;

/// The transport starts under `RecordSchema`, the newest record schema it
/// reads and writes. A cursor and server fields kept under an older schema
/// are left behind, so records the older build skipped are fetched again and
/// no upload builds on a server copy it could not read; everything else is
/// kept.
///
/// The first time, it carries the state an installed release kept in the
/// transport's own file into the device store: `Legacy` is that file exactly
/// as the host read it, or null when there is none. A pause older builds kept
/// for an ordinary record race is dropped. The state and the adoption's
/// marker are saved together, and the file is never changed, so a release
/// from before this one still reads it. Later, `Legacy` is ignored and the
/// host need not read the file: `CloudTransportState.IsAdopted` says so. A
/// file that does not read is `LegacyCloudStateUnreadable`, and nothing is
/// adopted.
[MessageLimit(128 * 1024 * 1024)]
public sealed record OpenCloudTransport(int RecordSchema, byte[]? Legacy) : CloudTransportIntent;
