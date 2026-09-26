namespace CrestCore.Contracts;

/// Carries the link preferences an installed release kept in its defaults
/// into the device store, once, and publishes them. `Preferences` is the
/// document that release saved under `crest.link-preferences.v1`, or null when
/// it saved none; the release's own copy stays where it is. A value this build
/// cannot read keeps its default. A device that adopted them before, or keeps
/// no file, adopts nothing and still publishes its preferences, so the
/// platform reads them from launch.
public sealed record AdoptLinkPreferences(byte[]? Preferences) : LinkIntent;
