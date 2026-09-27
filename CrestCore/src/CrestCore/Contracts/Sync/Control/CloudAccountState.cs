namespace CrestCore.Contracts;

/// What iCloud says of the signed-in account.
///
/// A state travels as its index in `All`, so `All` is append-only.
public sealed class CloudAccountState {
    #region Variables

    public static readonly CloudAccountState Checking = new(name: "checking");
    public static readonly CloudAccountState Available = new(name: "available");
    public static readonly CloudAccountState NoAccount = new(name: "noAccount");
    public static readonly CloudAccountState Restricted = new(name: "restricted");
    public static readonly CloudAccountState TemporarilyUnavailable = new(name: "temporarilyUnavailable");
    public static readonly CloudAccountState CouldNotDetermine = new(name: "couldNotDetermine");

    public static IReadOnlyList<CloudAccountState> All { get; } =
        [Checking, Available, NoAccount, Restricted, TemporarilyUnavailable, CouldNotDetermine];

    public string Name { get; }

    #endregion

    #region Constructors

    private CloudAccountState(string name) => Name = name;

    #endregion
}
