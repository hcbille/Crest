namespace CrestCore.Contracts;

/// Completes what a person typed, `Typed`, as an address the Space already
/// knows: `Suffix` follows the text as typed, and accepting the completion
/// leaves `Accepted`, which adds the scheme when the address is not https.
public sealed record AddressCompletion(string Typed, string Suffix, string Accepted);
