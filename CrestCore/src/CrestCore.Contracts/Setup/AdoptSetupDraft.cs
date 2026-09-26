namespace CrestCore.Contracts;

/// Carries the unfinished manual setup an installed release kept in its
/// defaults into the device store, once. `Draft` is the document that release
/// saved under `BrowserManualSetupDraft`, or null when it saved none; the
/// release's own copy stays where it is. Only a platform that keeps an
/// unfinished setup takes it, and one the store already keeps wins. A device
/// that adopted it before, or keeps no file, adopts nothing. The adopted
/// setup waits for `BeginManualSetup`, so nothing is published.
public sealed record AdoptSetupDraft(byte[]? Draft) : SetupDraftIntent;
