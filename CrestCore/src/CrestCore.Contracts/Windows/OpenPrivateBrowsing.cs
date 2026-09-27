namespace CrestCore.Contracts;

/// The person opened private browsing in the private window `WindowId` names
/// from the window `FromWindowId` names. Until private browsing opens again,
/// the pages of the private window's workspace borrow the regular profile of
/// the Space that window shows now, while that Space stays unlocked and is not
/// being deleted, and `CreatePage` names it. A window over a private
/// workspace lends none.
public sealed record OpenPrivateBrowsing(Guid WindowId, Guid FromWindowId) : WindowIntent;
