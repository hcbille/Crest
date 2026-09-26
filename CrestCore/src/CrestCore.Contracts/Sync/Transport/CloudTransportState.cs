namespace CrestCore.Contracts;

/// The cloud transport's state on this device. `RequiresFullPull` holds while
/// a download may have advanced the cursor past content the session never
/// took, until a full snapshot is applied. `AwaitsAccountDecision` pauses
/// sync after the account changed until the person chooses which copy to
/// keep. `OverwritesCloud` holds after the person chose this device's copy,
/// until every record it staged has uploaded: meanwhile fetched content is
/// not merged and a record the server changed is uploaded again.
/// `EngineState` is the sync engine's own saved state, which only the
/// transport reads. `IsAdopted` tells whether the state an installed
/// release kept in its file was carried into the device store yet.
public sealed record CloudTransportState(
    bool RequiresFullPull,
    bool AwaitsAccountDecision,
    bool OverwritesCloud,
    byte[]? EngineState,
    bool IsAdopted);
