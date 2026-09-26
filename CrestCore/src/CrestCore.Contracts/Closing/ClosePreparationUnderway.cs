namespace CrestCore.Contracts;

/// Another close preparation, `RequestId`, is still under way.
public sealed record ClosePreparationUnderway(Guid RequestId) : Rejection;
