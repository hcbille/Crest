namespace CrestCore.Contracts;

/// Opens setup over the workspace for a person arriving by `Entry`, on the
/// entry's first step, in place of any setup open before. A manual setup kept
/// from before is kept for the manual-setup step only where the platform keeps
/// one and the entry does not start it over.
///
/// Refused with `PersistentWorkspaceRequired` for a workspace setup cannot
/// change.
public sealed record StartSetup(Guid WorkspaceId, SetupEntry Entry) : SetupFlowIntent;
