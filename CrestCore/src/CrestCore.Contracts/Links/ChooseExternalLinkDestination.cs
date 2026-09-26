namespace CrestCore.Contracts;

/// Chooses where a link from another app opens when no route takes it, and,
/// for a destination that asks for one, the Space it opens in; null keeps the
/// Space chosen before.
public sealed record ChooseExternalLinkDestination(ExternalLinkDestination Destination, Guid? SpaceId) : LinkIntent;
