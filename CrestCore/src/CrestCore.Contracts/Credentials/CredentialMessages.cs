namespace CrestCore.Contracts;

#region Queries

/// What one credential form observation does to the page's credential state.
/// `Hint` is the page's remembered username from an earlier login step and
/// `Pending` the submitted credential still waiting for a sign-in; neither
/// carries the username or the password. `Now` is in seconds since 1970.
public sealed record CredentialCapture(CredentialFormFacts Facts, CredentialUsernameHint? Hint,
    CredentialPendingCandidate? Pending, double Now) : Query<CredentialCaptureDecision>;

/// The capture policy's answer for one observation. `ClearsUsernameHint` asks
/// the caller to forget a remembered username that no longer applies.
/// `AnchorsToField` says whether a fill prompt may point at the reported field.
/// `CandidateLifetime` and `UsernameHintLifetime` are the seconds a captured
/// candidate and a remembered username stay usable.
public sealed record CredentialCaptureDecision(CredentialCaptureAction Action, CredentialUsernameSource UsernameSource,
    bool ClearsUsernameHint, bool IsCrossOriginFrame, bool AnchorsToField, double CandidateLifetime,
    double UsernameHintLifetime);

/// What the page's credential state does with one observation.
public enum CredentialCaptureAction {
    Ignore,
    RememberUsername,
    DismissFill,
    OfferFill,
    CaptureCandidate,
    OfferSave,
    KeepPending,
    DiscardPending
}

/// Where a fill request or save candidate takes its username from.
public enum CredentialUsernameSource { None, Explicit, Hint }

/// What one validated form message says, without its credential material. The
/// platform keeps the username and password values; the core only learns
/// whether they are present.
public sealed record CredentialFormFacts(CredentialCaptureEvent Event, CredentialOrigin FrameOrigin,
    CredentialOrigin TopLevelOrigin, bool IsMainFrame, bool HasFormId, bool HasUsername, bool HasPassword,
    CredentialPasswordKind? PasswordKind, bool? HasVisiblePasswordField, bool HasFillTarget);

/// A credential form observation, or `Filled` when the native layer finished
/// filling a saved credential into the page.
public enum CredentialCaptureEvent { Username, Focus, Submit, DocumentState, Filled }

/// A submitted credential still waiting for the page to show it signed in.
/// `SubmittedAt` is in seconds since 1970.
public sealed record CredentialPendingCandidate(CredentialOrigin Origin, double SubmittedAt);

/// The page's remembered username from an earlier step of a multi-step login,
/// without the username itself. `CapturedAt` is in seconds since 1970.
public sealed record CredentialUsernameHint(CredentialOrigin Origin, CredentialOrigin TopLevelOrigin, double CapturedAt);

/// Whether a fill request may put a saved credential or a generated password
/// into a password field of this kind.
public sealed record CredentialFill(CredentialFillSource Source, CredentialPasswordKind PasswordKind)
    : Query<CredentialFillDecision>;

/// Whether a fill may go ahead.
public sealed record CredentialFillDecision(bool IsAllowed);

/// What the person asked to fill: a saved credential or a generated password.
public enum CredentialFillSource { Saved, Generated }

/// Whether a password field asks for the account's current password or for a
/// new one, as the form classifier reported it.
public enum CredentialPasswordKind { Current, New }

/// What saving a candidate means for the vault. `MatchId` is the record
/// `CredentialSaveMatch` chose. `Stored` is the platform's comparison of the
/// candidate against that record's secret, or null when there was no match or
/// the secret could not be read.
public sealed record CredentialSave(Guid? MatchId, CredentialStoredComparison? Stored) : Query<CredentialSavePlan>;

/// The platform's comparison of a candidate against the stored secret of the
/// matched record. The core never receives either password, only this answer.
public sealed record CredentialStoredComparison(Guid Id, bool PasswordMatches);

/// Whether a save candidate submitted at `SubmittedAt` may still be planned or
/// committed at `Now`. Both are in seconds since 1970.
public sealed record CredentialSaveCheck(CredentialOrigin Origin, CredentialOrigin TopLevelOrigin, double SubmittedAt,
    double Now) : Query<CredentialSaveVerdict>;

/// Whether a save candidate is still accepted, or why it is not.
public sealed record CredentialSaveVerdict(CredentialSaveValidity Validity);

/// Whether a save candidate may still be planned or committed.
public enum CredentialSaveValidity { Accepted, InsecureOrigin, Stale }

/// The most recent record for the same account as `Username`, compared after
/// canonical composition and ignoring case. Every record carries its username;
/// no password crosses.
public sealed record CredentialSaveMatch(string Username, IReadOnlyList<CredentialRecord> Records) : Query<CredentialChoice>;

/// The record a credential rule chose, or null when none qualifies.
public sealed record CredentialChoice(Guid? CredentialId);

/// The most recent of a batch of saved credentials. The records need no
/// usernames. Winners of separate batches reduce to the same answer as one
/// batch, so a caller may split a list longer than the batch limit.
public sealed record MostRecentCredential(IReadOnlyList<CredentialRecord> Records) : Query<CredentialChoice>;

/// How to compose a generated password of `Length` characters, or of the
/// default length when it is null. The password itself never exists in the core.
public sealed record StrongPassword(int? Length) : Query<StrongPasswordRecipe>;

/// How a strong password is composed: its length and the character groups it
/// draws from. The platform draws one character from every group, fills the
/// rest from all groups and shuffles, using its own secure random source, so
/// the password itself never exists in the core.
public sealed record StrongPasswordRecipe(int Length, IReadOnlyList<string> Groups);

#endregion

#region Rejections

/// One question carried more than `Limit` records.
public sealed record CredentialRecordLimitReached(int Limit) : Rejection;

/// Two records in one question share an identity.
public sealed record DuplicateCredential() : Rejection;

/// A credential date or clock reading is not finite.
public sealed record InvalidCredentialDate() : Rejection;

/// A credential origin is not a canonical HTTP(S) origin.
public sealed record InvalidCredentialOrigin() : Rejection;

/// A record an account match needs has no username.
public sealed record InvalidCredentialRecord() : Rejection;

/// A username to match is empty, or a username is longer than its limit.
public sealed record InvalidCredentialUsername() : Rejection;

/// A generated password's length is outside `Minimum` to `Maximum`.
public sealed record InvalidPasswordLength(int Minimum, int Maximum) : Rejection;

/// The platform compared the candidate against a record other than the match.
public sealed record StaleCredentialComparison() : Rejection;

#endregion

#region Models

/// What saving a submitted credential means for the vault.
public enum CredentialSavePlanKind { Create, Update, AlreadyStored }

#endregion
