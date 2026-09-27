namespace CrestCore.Contracts;

/// Whether websites in Crest can use the system's passkey providers, from the
/// platform's build, device and authorization facts.
public sealed record PasskeyAccess(bool HasManagedCapability, PasskeyDeviceConfiguration DeviceConfiguration,
    PasskeyAuthorizationState AuthorizationState) : Query<PasskeyAccessVerdict>;

/// Where passkey access for websites stands.
public sealed record PasskeyAccessVerdict(PasskeyAccessStatus Status);

/// The platform's browser-passkey authorization for Crest.
public enum PasskeyAuthorizationState { Authorized, Denied, NotDetermined }

/// Whether the device has passkeys set up, as far as the platform can tell.
public enum PasskeyDeviceConfiguration { Configured, NotConfigured, Unknown }

/// Whether a save prompt goes on to offer the password to the system's
/// Passwords app: only when the Space opted in, the launch can, and the window
/// is not private.
public sealed record SystemPasswordOffer(bool SpaceOffersSystemPasswords, SystemPasswordWriteThroughAvailability Availability,
    bool IsPrivateBrowsing) : Query<SystemPasswordOfferDecision>;

/// Whether the save prompt offers the password to the system's Passwords app.
public sealed record SystemPasswordOfferDecision(bool Offers);

/// Whether Crest may offer a saved password to the system's Passwords app.
public enum SystemPasswordWriteThroughAvailability {
    Available,
    UnsupportedPlatform,
    IsolatedLaunch,
    SystemVersionRequired,
    ManagedBrowserCapabilityRequired
}

/// Whether this launch can offer saved passwords to the system's Passwords app.
/// `SupportsSystemPasswordSaving` says the operating system has the API that
/// saves one; `IsLaunchIsolated` says this launch keeps away from the person's
/// own stores.
public sealed record SystemPasswordWriteThrough(bool IsMobilePlatform, bool SupportsSystemPasswordSaving,
    bool HasManagedBrowserCapability, bool IsLaunchIsolated) : Query<SystemPasswordWriteThroughSupport>;

/// Whether this launch may offer saved passwords to the system's Passwords app,
/// or why not.
public sealed record SystemPasswordWriteThroughSupport(SystemPasswordWriteThroughAvailability Availability);
