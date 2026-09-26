namespace CrestCore.Contracts;

/// Where a password another browser keeps belongs: the profile it was saved
/// in and its site's host. The password itself never crosses for routing.
public sealed record ImportPasswordSource(string ProfileName, string Host);
