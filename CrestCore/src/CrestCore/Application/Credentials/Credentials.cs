using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// The credentials and passkeys area: capture, fill and save decisions, the
/// generated-password recipe, passkey access, the system Passwords offer, and
/// password files read for an import and written for an export.
///
/// It holds no state. Capture, fill and save take only identities and
/// metadata: form facts say whether a username or password is present, never
/// what it is, and the save plan takes the platform's comparison instead of a
/// stored secret. Importing and exporting a password file are the only
/// questions that carry passwords: the file itself, the passwords the Space
/// keeps that an import is compared against, the passwords another browser
/// brings, and the passwords an export writes. The core answers them from the
/// question alone and keeps none of it: every record that holds a password
/// is marked `HoldsSecrets`, names no secret in its text form, and is
/// reachable from no change, stored session or sync journal record, and the
/// buffer an answer crosses in is cleared when it is freed.
public sealed class Credentials {
    #region Actions - Capture and fill

    public CredentialCaptureDecision Answer(CredentialCapture query) {
        ArgumentNullException.ThrowIfNull(query);
        return CredentialCapturePolicy.Decide(query.Facts, query.Hint, query.Pending, query.Now);
    }

    public CredentialFillDecision Answer(CredentialFill query) {
        ArgumentNullException.ThrowIfNull(query);
        return new(CredentialCapturePolicy.Offers(query.Source, query.PasswordKind));
    }

    #endregion

    #region Actions - Saving

    public CredentialSaveVerdict Answer(CredentialSaveCheck query) {
        ArgumentNullException.ThrowIfNull(query);
        return new(CredentialCapturePolicy.SaveValidity(query.Origin, query.TopLevelOrigin, query.SubmittedAt, query.Now));
    }

    public CredentialChoice Answer(MostRecentCredential query) {
        ArgumentNullException.ThrowIfNull(query);
        return new(CredentialRecencyPolicy.MostRecent(query.Records)?.Id);
    }

    public CredentialChoice Answer(CredentialSaveMatch query) {
        ArgumentNullException.ThrowIfNull(query);
        return new(CredentialSavePolicy.Match(query.Username, query.Records)?.Id);
    }

    public CredentialSavePlan Answer(CredentialSave query) {
        ArgumentNullException.ThrowIfNull(query);
        return CredentialSavePolicy.Plan(query.MatchId, query.Stored);
    }

    public StrongPasswordRecipe Answer(StrongPassword query) {
        ArgumentNullException.ThrowIfNull(query);
        return StrongPasswordPolicy.Recipe(query.Length);
    }

    #endregion

    #region Actions - Password files

    /// What importing the password file the query holds means. Throws
    /// `Rejected` with `InvalidCredentialFile` for a file that cannot import.
    public CredentialImportPlan Answer(CredentialImportPreview query) {
        ArgumentNullException.ThrowIfNull(query);
        var file = CredentialFile.Read(query.Document);
        return CredentialImportPlanning.Plan(file.Format, file.Credentials, file.Rejections, query.Existing);
    }

    /// What importing another browser's passwords means, as its own password
    /// file would.
    public CredentialImportPlan Answer(PasswordImportPreview query) {
        ArgumentNullException.ThrowIfNull(query);
        return CredentialImportPlanning.Plan(CredentialFileFormat.Browser, query.Credentials, [], query.Existing);
    }

    /// The Space's password file.
    public CredentialExportFile Answer(CredentialExport query) => CredentialExporting.File(query);

    #endregion

    #region Actions - Passkeys and system passwords

    public PasskeyAccessVerdict Answer(PasskeyAccess query) {
        ArgumentNullException.ThrowIfNull(query);
        return new(PasskeyAccessPolicy.Status(query.HasManagedCapability, query.DeviceConfiguration, query.AuthorizationState));
    }

    public SystemPasswordWriteThroughSupport Answer(SystemPasswordWriteThrough query) {
        ArgumentNullException.ThrowIfNull(query);
        return new(PasskeyAccessPolicy.WriteThroughAvailability(query.IsMobilePlatform, query.SupportsSystemPasswordSaving,
            query.HasManagedBrowserCapability, query.IsLaunchIsolated));
    }

    public SystemPasswordOfferDecision Answer(SystemPasswordOffer query) {
        ArgumentNullException.ThrowIfNull(query);
        return new(PasskeyAccessPolicy.OffersWriteThrough(query.SpaceOffersSystemPasswords, query.Availability,
            query.IsPrivateBrowsing));
    }

    #endregion
}
