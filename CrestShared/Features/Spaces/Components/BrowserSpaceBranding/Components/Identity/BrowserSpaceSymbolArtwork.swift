import SwiftUI

/// A single original-color platform image used anywhere SwiftUI bridges a Space
/// icon into a native control. Without this boundary, menus and pickers can
/// flatten a layered crest into one template symbol or interpret its layers as
/// separate control elements.
struct BrowserSpaceSymbolArtwork: View {
    let identity: BrowserSpaceIdentity
    let size: CGFloat
    let lockSize: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @State private var renderedArtwork: BrowserSpaceRenderedSymbolArtwork?

    init(space: some BrowserSpaceIdentifying, size: CGFloat, lockSize: CGFloat) {
        self.init(identity: space.identity, size: size, lockSize: lockSize)
    }

    init(identity: BrowserSpaceIdentity, size: CGFloat, lockSize: CGFloat) {
        self.identity = identity
        self.size = size
        self.lockSize = lockSize
    }

    var body: some View {
        Group {
            if let renderedArtwork {
                // The renderer already supplies this exact point size. Native
                // picker cells stretch resizable images to their label width.
                renderedArtwork.image
                    .renderingMode(.original)
                    .interpolation(.high)
            } else {
                if let emoji = BrowserIconSymbol.emoji(from: identity.symbol) {
                    Text(emoji)
                        .font(.system(size: size * 0.68))
                } else {
                    Image(systemName: identity.symbol)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(identity.branding.resolvedSymbolColor.color)
                        .padding(size * 0.2)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: artworkIdentity) {
            guard !Task.isCancelled else { return }
            let currentIdentity = artworkIdentity
            let content = BrowserSpaceSymbolArtworkContent(
                identity: identity,
                size: size,
                lockSize: lockSize
            )
            .environment(\.colorScheme, colorScheme)
            let image = BrowserSpaceSymbolArtworkCache.shared.image(for: currentIdentity) {
                BrowserPlatformSpaceSymbolArtworkRenderer.image(
                    for: content,
                    size: size,
                    scale: displayScale,
                    fallbackSystemImage: identity.symbol
                )
            }
            guard !Task.isCancelled, currentIdentity == artworkIdentity else { return }
            renderedArtwork = BrowserSpaceRenderedSymbolArtwork(
                identity: currentIdentity,
                image: image
            )
        }
    }

    private var artworkIdentity: BrowserSpaceSymbolArtworkIdentity {
        BrowserSpaceSymbolArtworkIdentity(
            branding: identity.branding,
            symbol: identity.symbol,
            requiresAuthentication: identity.requiresAuthentication,
            size: size,
            lockSize: lockSize,
            colorScheme: colorScheme,
            displayScale: displayScale
        )
    }
}

/// Native picker and menu labels often request the same crest at the same size.
/// Share those renders, with a fixed limit as sliders generate new appearances.
@MainActor
final class BrowserSpaceSymbolArtworkCache {
    static let shared = BrowserSpaceSymbolArtworkCache()
    private let capacity: Int
    private var entries: [BrowserSpaceRenderedSymbolArtwork] = []

    init(capacity: Int = 64) {
        self.capacity = max(1, capacity)
    }

    func image(for identity: BrowserSpaceSymbolArtworkIdentity, render: () -> Image) -> Image {
        if let index = entries.firstIndex(where: { $0.identity == identity }) {
            let entry = entries.remove(at: index)
            entries.append(entry)
            return entry.image
        }
        let image = render()
        if entries.count == capacity { entries.removeFirst() }
        entries.append(BrowserSpaceRenderedSymbolArtwork(identity: identity, image: image))
        return image
    }
}
