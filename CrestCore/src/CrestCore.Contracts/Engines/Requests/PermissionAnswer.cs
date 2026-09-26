namespace CrestCore.Contracts;

/// How a site's permission request was answered.
public enum PermissionAnswer {
    /// Allowed, and remembered for the site.
    Allow,

    /// Allowed for this request only.
    AllowOnce,

    /// Blocked, and remembered for the site.
    Block,

    /// Not answered; the site may ask again.
    Dismiss
}
