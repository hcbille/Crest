namespace CrestCore.Contracts;

#region Intents

/// Gives the persistent workspace the preferences the settings kept before the
/// core owned them, once: a workspace that already holds preferences keeps
/// them, so a later launch never imports over a choice.
public sealed record ImportAppPreferences(Guid WorkspaceId, LegacyAppPreferences Legacy) : SessionIntent(WorkspaceId);

/// The behavior preferences as an older release's settings stored them, each
/// null when it was never saved. Terms are the stored spellings, which the core
/// reads tolerantly, and `TranslationRules` is the rule set as the settings
/// stored it, a JSON document.
public sealed record LegacyAppPreferences(
    string? StartupBehavior,
    bool? OffersTranslation,
    bool? AutomaticallyTranslates,
    string? TranslationRules,
    bool? ChecksSpelling,
    bool? AutomaticallyEntersPictureInPicture,
    string? SavedTabClosePolicy,
    bool? SavedTabFaviconReturnsToSavedUrl,
    bool? SplitFocusFollowsMouse);

/// Sets the app-wide behavior preferences. The persistent workspace keeps
/// them on this device; they never sync. The translation rules keep to the
/// rule set's own limits.
public sealed record SetAppPreferences(Guid WorkspaceId, AppPreferences Preferences) : SessionIntent(WorkspaceId);

/// Records whether pages in `SourceLanguage` are translated into
/// `TargetLanguage`. Region aliases of the source share one choice, so an
/// alias cannot get around turning translation off; a blank source changes
/// nothing.
public sealed record SetTranslationRule(Guid WorkspaceId, string SourceLanguage, string TargetLanguage, bool IsEnabled)
    : SessionIntent(WorkspaceId);

#endregion

#region Queries

/// Whether each of `Candidates` names the same translation language as
/// `Language`. It reads no state, so a host may ask it without an app.
public sealed record LanguagesMatching(string Language, IReadOnlyList<string> Candidates) : Query<LanguageMatches>;

/// For each candidate, in order, whether it names the asked language.
public sealed record LanguageMatches(IReadOnlyList<bool> Matches);

/// How this launch treats the person's data, decided before any session
/// exists: whether it stays out of the installed profile, whether page and
/// extension storage forget, and whether it shows the installed app's UI. Its
/// startup answer is the one for a person who never chose; `LaunchPlan` reads
/// the saved choice once a workspace keeps one. It reads no state, so the host
/// asks it before it makes an app.
public sealed record LaunchIsolation(DevicePlatform Platform, LaunchEnvironment Environment) : Query<LaunchDecision>;

/// How one launch treats the person's data and what its first window opens.
/// An isolated launch never reads or writes the installed profile.
/// `UsesEphemeralProfileStorage` keeps page and extension web storage in the
/// same privacy class: both forget, unless a named isolated profile persists
/// both. `PresentsInstalledApplicationUI` is false only under the test runtime.
public sealed record LaunchDecision(bool RequiresIsolation, bool UsesEphemeralProfileStorage, bool PresentsInstalledApplicationUI,
    StartupBehavior Startup);

/// How this launch treats the person's data and what its first window opens,
/// with the startup choice the persistent workspace keeps. First-run setup
/// that owns the first window is an active launch gate.
public sealed record LaunchPlan(Guid WorkspaceId, DevicePlatform Platform, LaunchEnvironment Environment, bool HasActiveLaunchGate)
    : Query<LaunchDecision>;

/// The rule among `Rules` that applies to pages in `SourceLanguage`, whose
/// region aliases share it, and the language such pages are translated into.
/// It reads no state, so a host may ask it without an app.
public sealed record TranslationChoice(IReadOnlyList<TranslationRule> Rules, string SourceLanguage) : Query<TranslationDecision>;

/// The rule that applies to a source language, or null, and the language its
/// pages are translated into, or null when they are not.
public sealed record TranslationDecision(TranslationRule? Rule, string? Target);

#endregion

#region Rejections

/// A language identifier is longer than `Limit` characters.
public sealed record LanguageTooLong(int Limit) : Rejection;

/// Only the persistent workspace keeps the app-wide preferences and takes
/// imported Spaces.
public sealed record PersistentWorkspaceRequired(Guid WorkspaceId) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Open a regular window to do this.";

    #endregion
}

/// Translation rules already cover `Limit` source languages.
public sealed record TranslationRuleLimitReached(int Limit) : Rejection;

#endregion
