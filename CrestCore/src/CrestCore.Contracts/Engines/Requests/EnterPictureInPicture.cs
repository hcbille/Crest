namespace CrestCore.Contracts;

/// Moves the video the page is playing, or last played before it left the
/// screen, into Picture in Picture. False when it has none to move or one is
/// already there.
public sealed record EnterPictureInPicture(Guid PageId) : PageRequest<bool>;
