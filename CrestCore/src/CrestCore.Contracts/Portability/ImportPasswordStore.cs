namespace CrestCore.Contracts;

/// A profile's store of saved passwords: `Id`, the name the browser keeps the
/// profile under, the `ProfileName` the person gave it, and the store's path.
public sealed record ImportPasswordStore(string Id, string ProfileName, string Path);
