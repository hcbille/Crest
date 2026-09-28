import SwiftUI

/// A mark a tab's icon wears in its bottom-trailing corner, such as the engine
/// its page runs on.
///
/// It sits on a disc of its own drawn over the window's ground rather than
/// over the icon: a favicon can be any colour, and the mark has to stay
/// readable against all of them. A sidebar row and a pinned tile draw it at
/// the same size, hung off the same corner, so pinning a tab changes nothing
/// about how it is marked. The disc is sized against the row's 18pt favicon,
/// the smaller of the two, so it never grows into the icon it annotates.
///
/// Drawn over the favicon after the tab's residency fade, so the mark keeps
/// full strength on a tab the shell no longer holds in memory.
///
/// The badge says nothing to VoiceOver. A tile is one button and a row is a
/// container with one labelled button in it, and both write their value from
/// outside, so anything declared in here would be merged away or read twice.
/// Whoever draws a badge adds what it means to that value instead.
struct TabFaviconBadge: View {
    // MARK: - Static Variables

    /// The disc the artwork is drawn on, which keeps it readable over a
    /// favicon of any colour.
    static let diameter: CGFloat = 10

    /// The artwork inside that disc, inset far enough that the disc still
    /// reads as a ring around it at either favicon size.
    static let artworkSize: CGFloat = 6.5

    /// How far the badge hangs past the favicon's corner, so it reads as
    /// attached to the icon rather than drawn on top of it.
    static let overhang: CGFloat = 2

    // MARK: - Variables

    /// What the badge shows. A template image, such as a symbol, draws in the
    /// secondary ink; other artwork draws as it was authored.
    let artwork: Image

    /// What the badge says when the pointer rests on it.
    let title: Text

    /// The favicon's scale against a default-density row's, which the badge
    /// follows so it keeps its proportion to the icon.
    var scale: CGFloat = 1

    var body: some View {
        artwork
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .foregroundStyle(.secondary)
            .frame(width: Self.artworkSize * scale, height: Self.artworkSize * scale)
            .frame(width: Self.diameter * scale, height: Self.diameter * scale)
            .background(CrestColor.chromeSurface, in: .circle)
            .background(.background, in: .circle)
            .overlay {
                Circle()
                    .strokeBorder(CrestColor.subtleBorder, lineWidth: CrestLayout.hairline)
            }
            .offset(x: Self.overhang * scale, y: Self.overhang * scale)
            .accessibilityHidden(true)
            .help(title)
    }
}

#if DEBUG
    #Preview("Badged icons") {
        HStack(spacing: CrestSpacing.medium) {
            ForEach(EngineKind.all, id: \.self) { engine in
                RoundedRectangle(cornerRadius: TabFaviconMetrics.cornerRadius(for: TabFaviconMetrics.defaultSize))
                    .fill(.tint)
                    .frame(width: TabFaviconMetrics.defaultSize, height: TabFaviconMetrics.defaultSize)
                    .overlay(alignment: .bottomTrailing) {
                        TabFaviconBadge(artwork: Image(systemName: engine.symbol), title: Text(engine.pageDescription))
                    }
            }
        }
        .padding()
    }
#endif
