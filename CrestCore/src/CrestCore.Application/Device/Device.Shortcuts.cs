using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

#region Types

/// What one shortcut intent needs: the commands this device offers, whose
/// bindings it reads, and where it publishes them.
internal sealed record ShortcutTurn(IReadOnlyList<ShortcutCommand> Offered, ChangeFeed Changes);

#endregion

/// This device's shortcut choices, which the device store keeps. What a
/// choice binds is read on the device's platform, over the commands its
/// default engine offers.
internal sealed partial class Device : IShortcutIntentHandler<ShortcutTurn> {
    #region Variables

    private ShortcutOverrides shortcuts = ShortcutOverrides.None;

    #endregion

    #region Actions - Shortcut intents

    /// Runs one shortcut intent over the commands this device offers, holding
    /// the device lock, publishing the bindings when any of them changed.
    public void Handle(ShortcutIntent intent, ShortcutTurn turn) {
        ArgumentNullException.ThrowIfNull(intent);
        ArgumentNullException.ThrowIfNull(turn);
        lock (gate) intent.Dispatch(this, turn);
    }

    /// An adoption always publishes the bindings. The caller holds the device
    /// lock, as for each shortcut intent.
    public void Handle(AdoptShortcuts adoption, ShortcutTurn turn) {
        Adopt(adoption);
        turn.Changes.Publish(Shortcuts(turn.Offered));
    }

    public void Handle(AssignShortcut assigning, ShortcutTurn turn) =>
        Revise(shortcuts.Assigning(assigning.Command, Chord(assigning.Keys), turn.Offered, platform), turn);

    public void Handle(ReassignShortcut reassigning, ShortcutTurn turn) =>
        Revise(shortcuts.Reassigning(reassigning.Command, Chord(reassigning.Keys), turn.Offered, platform), turn);

    public void Handle(UnassignShortcut unassigning, ShortcutTurn turn) => Revise(shortcuts.Unassigning(unassigning.Command, platform), turn);

    public void Handle(ResetShortcut resetting, ShortcutTurn turn) => Revise(shortcuts.Resetting(resetting.Command), turn);

    public void Handle(ResetShortcuts resetting, ShortcutTurn turn) => Revise(ShortcutOverrides.None, turn);

    /// Keeps `revised`, and publishes the bindings when any of them changed.
    /// The caller holds the device lock.
    private void Revise(ShortcutOverrides revised, ShortcutTurn turn) {
        if (revised.SameAs(shortcuts)) return;
        var before = Shortcuts(turn.Offered);
        shortcuts = revised;
        storage?.EnqueueDevice(Records());
        var after = Shortcuts(turn.Offered);
        if (after.IsCustomized != before.IsCustomized || !after.Bindings.SequenceEqual(before.Bindings)) turn.Changes.Publish(after);
    }

    /// Carries the choices an installed release kept into the device store
    /// once, after any the store already holds, and saves them before
    /// returning. The caller holds the device lock.
    private void Adopt(AdoptShortcuts intent) {
        if (storage is not { } target || adopted.Contains(DeviceAdoption.Shortcuts)) return;
        var merged = ShortcutOverrides.Restore([.. shortcuts.Chords, .. LegacyShortcutDocument.Read(intent.Overrides)]);
        var carried = Records().Adopting(DeviceAdoption.Shortcuts) with { Shortcuts = merged };
        try {
            target.SaveDevice(carried);
        } catch (StorageException error) {
            throw new Rejected(new SaveFailed(error.Reason));
        }
        shortcuts = merged;
        adopted.Add(DeviceAdoption.Shortcuts);
        // Records handed to the store before this carry nothing adopted; these supersede them.
        target.EnqueueDevice(Records());
    }

    /// The bindings over `offered` when the commands this device offers
    /// changed from `before`, or null when no binding differs.
    public ShortcutsChanged? ShortcutsAfter(IReadOnlyList<ShortcutCommand> before, IReadOnlyList<ShortcutCommand> offered) {
        lock (gate) {
            var previous = Shortcuts(before);
            var next = Shortcuts(offered);
            return next.Bindings.SequenceEqual(previous.Bindings) ? null : next;
        }
    }

    /// Every offered command's binding. The caller holds the device lock.
    private ShortcutsChanged Shortcuts(IReadOnlyList<ShortcutCommand> offered) =>
        new(shortcuts.Bindings(offered, platform), shortcuts.IsCustomized);

    /// The chord `keys` spell, or `InvalidShortcut` for keys that can never be one.
    private static ShortcutChord Chord(KeyCombination keys) =>
        ShortcutChord.Usable(keys) ?? throw new Rejected(new InvalidShortcut(keys));

    #endregion
}
