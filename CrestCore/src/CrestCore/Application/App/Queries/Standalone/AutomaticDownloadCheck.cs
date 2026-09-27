using CrestCore.Application;
using CrestCore.Domain;

namespace CrestCore.Contracts;

/// Whether a download a page starts goes ahead, is refused or asks first:
/// whether a person's gesture started it or approved a retry, the site's saved
/// decision, and whether the page has already had its one automatic download
/// while that decision is Ask.
public sealed record AutomaticDownloadCheck(bool UserInitiated, bool UserApprovedRetry, SitePermissionDecision SavedDecision,
    bool HasAllowedAutomaticDownload) : StandaloneQuery<AutomaticDownloadVerdict> {
    #region Actions - Answering

    internal override AutomaticDownloadVerdict Answer(StandaloneContext context) =>
        AutomaticDownloadPolicy.Decide(UserInitiated, UserApprovedRetry, SavedDecision, HasAllowedAutomaticDownload);

    #endregion
}
