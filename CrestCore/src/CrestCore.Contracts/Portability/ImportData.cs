namespace CrestCore.Contracts;

/// What a browser keeps in its data folder: each profile with the files an
/// import reads, and each store of saved passwords, in the order a person
/// meets them there.
public sealed record ImportData(IReadOnlyList<ImportProfile> Profiles, IReadOnlyList<ImportPasswordStore> PasswordStores);
