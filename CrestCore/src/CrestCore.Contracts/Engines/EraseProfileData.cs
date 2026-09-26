namespace CrestCore.Contracts;

/// Erases everything the engine keeps for profile `ProfileId`, without
/// opening a page or starting anything the engine has not started. The
/// binding answers with `DataErased` for `ErasureId`.
public sealed record EraseProfileData(Guid ProfileId, bool Ephemeral, Guid ErasureId) : EngineCommand;
