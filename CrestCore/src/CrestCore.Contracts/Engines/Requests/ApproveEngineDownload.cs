namespace CrestCore.Contracts;

/// Keeps a download the engine warned about, while its warning is still the
/// one `ApprovalToken` names.
public sealed record ApproveEngineDownload(Guid ProfileId, string DownloadId, string ApprovalToken) : PageRequest<bool>;
