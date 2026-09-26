namespace CrestCore.Contracts;

/// The cloud transport's state after the intent that answered it.
public sealed record CloudTransportChanged(CloudTransportState State) : Change;
