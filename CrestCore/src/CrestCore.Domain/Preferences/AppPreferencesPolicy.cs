using CrestCore.Contracts;

namespace CrestCore.Domain;

/// How a translation rule edit changes the app-wide behavior preferences.
public static class AppPreferencesPolicy {
    #region Actions - Preferences

    /// Records a source language's translation choice through the rule set's
    /// alias rules.
    public static AppPreferences WithTranslationRule(this AppPreferences preferences, string source, string target, bool isEnabled) =>
        preferences with {
            TranslationRules = AutomaticTranslationRules.Restore(preferences.TranslationRules).Set(source, target, isEnabled).Rules
        };

    #endregion
}
