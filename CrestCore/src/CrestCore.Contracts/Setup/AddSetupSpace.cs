namespace CrestCore.Contracts;

/// Adds a new Space at the end of the manual setup, named for its place, such
/// as "Space 2", and wearing the accents in turn. Refused with
/// `SpaceLimitReached` when the setup holds as many Spaces as a workspace may.
public sealed record AddSetupSpace() : SetupDraftIntent;
