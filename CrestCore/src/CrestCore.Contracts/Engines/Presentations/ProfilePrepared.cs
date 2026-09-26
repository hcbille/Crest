namespace CrestCore.Contracts;

/// Whether the profile `PrepareProfile` asked for is ready.
public sealed record ProfilePrepared(Guid PreparationId, bool Ready) : EnginePresentation;
