namespace CrestCore.Contracts;

/// Starts, edits or ends the manual setup this device holds. Each publishes
/// the setup as it leaves it in `SetupDraftChanged`. An edit is refused with
/// `NoManualSetup` while no setup is in progress.
public abstract record SetupDraftIntent : Intent;

/// Moves setup on this device along. Each publishes setup as it leaves it in
/// `SetupFlowChanged`. One is refused with `NoSetup` while setup is not open,
/// and one that changes what setup works on with `SetupBusy` while it reads or
/// imports.
public abstract record SetupFlowIntent : Intent;

#region Setup

/// Adds a new Space at the end of the manual setup, named for its place, such
/// as "Space 2", and wearing the accents in turn. Refused with
/// `SpaceLimitReached` when the setup holds as many Spaces as a workspace may.
public sealed record AddSetupSpace() : SetupDraftIntent;

/// Carries whether an installed release completed setup, as it kept it under
/// `crest.onboarding.completed`, into the device store once, and publishes
/// whether this device has completed setup. A device that keeps no file keeps
/// `Completed` for this run; one that adopted it before keeps what it has.
public sealed record AdoptSetupCompletion(bool Completed) : SetupFlowIntent;

/// Carries the unfinished manual setup an installed release kept in its
/// defaults into the device store, once. `Draft` is the document that release
/// saved under `BrowserManualSetupDraft`, or null when it saved none; the
/// release's own copy stays where it is. Only a platform that keeps an
/// unfinished setup takes it, and one the store already keeps wins. A device
/// that adopted it before, or keeps no file, adopts nothing. The adopted
/// setup waits for setup's manual-setup step, so nothing is published.
public sealed record AdoptSetupDraft(byte[]? Draft) : SetupDraftIntent;

/// Gives the Space `SpaceId` of the manual setup the name and look of
/// `Customization`. The look is kept within the ranges every device draws;
/// the name is kept as typed.
public sealed record CustomizeSetupSpace(Guid SpaceId, SpaceCustomization Customization) : SetupDraftIntent;

/// Finishes setup from the window `WindowId`: applies the manual setup when
/// the person set Spaces up by hand, marks setup done on this device, and
/// publishes `SetupFinished` with the Space the Getting Started guide opens
/// in when the entry opens it.
///
/// Refused with `PersistentWorkspaceRequired` from a workspace setup cannot
/// change, `GuideSpaceLocked` while the Space the guide would open in is
/// locked, which the platform unlocks before finishing again, and whatever
/// refuses the manual setup.
public sealed record FinishSetup(Guid WindowId) : SetupFlowIntent;

/// Moves the Space `SpaceId` of the manual setup to where `TargetSpaceId`
/// stands, and makes the workspace take the setup's order.
public sealed record MoveSetupSpace(Guid SpaceId, Guid TargetSpaceId) : SetupDraftIntent;

/// Leaves the new Space `SpaceId` out of the manual setup. A setup never
/// removes an existing Space, so naming one changes nothing.
public sealed record RemoveSetupSpace(Guid SpaceId) : SetupDraftIntent;

/// Shows `Step`: the step Back or Next leads to, or another the person picked.
/// The review needs an import to review; the manual-setup step starts the
/// manual setup, or goes on with the one the device holds.
public sealed record ShowSetupStep(SetupStep Step) : SetupFlowIntent;

/// Opens setup over the workspace for a person arriving by `Entry`, on the
/// entry's first step, in place of any setup open before. A manual setup kept
/// from before is kept for the manual-setup step only where the platform keeps
/// one and the entry does not start it over.
///
/// Refused with `PersistentWorkspaceRequired` for a workspace setup cannot
/// change.
public sealed record StartSetup(Guid WorkspaceId, SetupEntry Entry) : SetupFlowIntent;

#endregion

#region Imports

/// Starts importing the review, before the platform reads the passwords it
/// brings and sends `ImportReviewedSpaces`.
///
/// Refused with `NoIncludedSpaces` when the review brings no Space.
public sealed record BeginImportCommit() : SetupFlowIntent;

/// Stops reading the current browser and goes back to choosing browsers.
public sealed record CancelImportRead() : SetupFlowIntent;

/// Makes the reviewed Space `SourceSpaceId` join the existing Space
/// `DestinationSpaceId`, taking that Space's name and look, or come in as a new
/// Space with its own when null.
public sealed record ChooseImportDestination(Guid SourceSpaceId, Guid? DestinationSpaceId) : SetupFlowIntent;

/// Goes on from choosing browsers: with none chosen, to setting up Spaces by
/// hand; otherwise to reading the next chosen browser, which the platform
/// then reads and hands back in `ReviewImport`.
public sealed record ContinueImport() : SetupFlowIntent;

/// Gives the reviewed Space `SourceSpaceId` the name and look of
/// `Customization`, kept within the ranges every device draws.
public sealed record CustomizeImportSpace(Guid SourceSpaceId, SpaceCustomization Customization) : SetupFlowIntent;

/// Reading or importing `Source` failed for `Reason`, in the words of what
/// refused it, `Detail`, when something did. Setup goes back to the step and
/// phase that can try again.
public sealed record FailImport(ImportSource Source, SetupFailureReason Reason, string? Detail) : SetupFlowIntent;

/// The review is imported, with `PasswordCount` of its passwords. Setup goes
/// on to the next chosen browser; after the last, to setting up Spaces by hand
/// when it walks the person through Crest, or else to what it did.
public sealed record FinishImportCommit(int PasswordCount) : SetupFlowIntent;

/// Brings the saved passwords that belong with the reviewed Space
/// `SourceSpaceId`, or leaves them out.
public sealed record IncludeImportPasswords(Guid SourceSpaceId, bool Included) : SetupFlowIntent;

/// Brings the reviewed Space `SourceSpaceId` with every tab its destination
/// does not already hold, or leaves it out with all of them.
public sealed record IncludeImportSpace(Guid SourceSpaceId, bool Included) : SetupFlowIntent;

/// Brings the tabs `TabIds` of the reviewed Space `SourceSpaceId`, or leaves
/// them out. Bringing a tab brings its Space.
public sealed record IncludeImportTabs(Guid SourceSpaceId, IReadOnlyList<Guid> TabIds, bool Included) : SetupFlowIntent;

/// The browsers the platform found installed, in the order it lists them,
/// which is the order setup imports from them.
public sealed record OfferImportSources(IReadOnlyList<ImportSource> Installed) : SetupFlowIntent;

/// Brings the tab `TabId` of the reviewed Space `SourceSpaceId` in
/// `Placement`, and with it the Space.
public sealed record PlaceImportTab(Guid SourceSpaceId, Guid TabId, TabPlacement Placement) : SetupFlowIntent;

/// The Spaces `Source` brings, as `ReadImport` answered them, with where each
/// of its saved passwords belongs, from which setup counts the passwords that
/// belong with each Space. Setup reviews them: each Space joins
/// the existing Space of the same name, leaving out the tabs that Space holds,
/// or else comes in as a new Space, and the person looks at the first.
///
/// Refused with `InvalidImport` for Spaces that repeat an identity or hold a
/// split repair would rewrite.
[MessageLimit(64 * 1024 * 1024)]
public sealed record ReviewImport(ImportSource Source, IReadOnlyList<SpaceState> Spaces, IReadOnlyList<ImportPasswordSource> Passwords)
    : SetupFlowIntent;

/// Shows the reviewed Space `SourceSpaceId`.
public sealed record ShowImportSpace(Guid SourceSpaceId) : SetupFlowIntent;

/// Chooses `Source` to import from, or leaves it out when chosen. Any review
/// or failure goes, and setup shows the browsers again.
public sealed record ToggleImportSource(ImportSource Source) : SetupFlowIntent;

#endregion
