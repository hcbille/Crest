import Foundation
import SwiftUI

/// One Space's download destination, as the shell that owns the file system
/// hands it over.
///
/// Choosing a folder is a system panel and remembering one is a security-scoped
/// bookmark, so the state and both system touches stay in the shell that has
/// them. This carries only what the section draws and the two things it can ask
/// for — which is also why ``explanation`` arrives rather than being written
/// here: the sentence names the machine the folder belongs to, and only the
/// shell knows what to call it.
struct BrowserSpaceDownloadSettings {
    /// Whether every download stops to ask where it should go.
    var asksWhereToSave: Binding<Bool>

    /// The display name of the folder downloads land in.
    var directoryName: String

    /// Whether ``directoryName`` is a folder the reader chose rather than the
    /// system default. The reset action has nothing to undo otherwise.
    var usesCustomDirectory: Bool

    /// Why the last folder change failed, if it did.
    var errorMessage: String?

    /// The footnote under the controls.
    var explanation: LocalizedStringKey

    /// Opens the shell's folder chooser.
    var chooseDirectory: () -> Void

    /// Returns this Space to the system download folder.
    var resetDirectory: () -> Void
}

/// Which sections of the Space settings superset a shell actually offers.
///
/// The two shells' Space settings diverge by what each shell can reach rather
/// than by which one it is: only the windowed shell picks a download folder,
/// because only it has a folder chooser to offer, and only it turns Crest
/// Passwords on from here, because the compact shell reaches that from its own
/// Passwords pane. So the pane is not a fixed list of sections with platform
/// holes cut in it — it is exactly the capabilities that arrived, and a shell
/// that gains one gets the section by passing it rather than by editing
/// ``BrowserSpaceSettingsSections``.
///
/// Browsing, the access policy, and deletion stay unconditional, because a
/// Space's settings without a search engine, a lock, or a way out is not a pane
/// anyone shipped.
struct BrowserSpaceSettingsCapabilities {
    /// Where this Space's downloads land, and how the reader changes it. Nil
    /// where the shell has no download-location UI of its own, because the
    /// system owns the destination there.
    var downloads: BrowserSpaceDownloadSettings?

    /// Whether this pane is also where the reader turns Crest Passwords on for
    /// the Space. False where the shell offers that in its Passwords pane
    /// instead.
    var editsCrestPasswords = false
}
