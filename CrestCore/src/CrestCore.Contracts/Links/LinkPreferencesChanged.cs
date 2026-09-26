namespace CrestCore.Contracts;

/// This device's link preferences changed, or were read as it opened.
public sealed record LinkPreferencesChanged(LinkPreferences Preferences) : Change;
