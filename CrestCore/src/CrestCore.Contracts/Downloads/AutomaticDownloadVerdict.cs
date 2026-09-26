namespace CrestCore.Contracts;

/// The action for one download and the throttle state its page and origin
/// carry into the next automatic download.
public sealed record AutomaticDownloadVerdict(AutomaticDownloadAction Action, bool HasAllowedAutomaticDownload);
