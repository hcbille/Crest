import SwiftUI

struct BrowserSpaceSymbolArtworkContent: View {
    let identity: BrowserSpaceIdentity
    let size: CGFloat
    let lockSize: CGFloat

    init(space: BrowserSpace, size: CGFloat, lockSize: CGFloat) {
        self.init(identity: BrowserSpaceIdentity(space: space), size: size, lockSize: lockSize)
    }

    init(identity: BrowserSpaceIdentity, size: CGFloat, lockSize: CGFloat) {
        self.identity = identity
        self.size = size
        self.lockSize = lockSize
    }

    var body: some View {
        BrowserSpaceIdentityIcon(identity: identity, size: size)
            .overlay(alignment: .bottomTrailing) {
                if identity.accessPolicy.requiresAuthentication {
                    Image(systemName: "lock.fill")
                        .font(.system(size: lockSize, weight: .bold))
                        .padding(2)
                        .background(.background, in: .circle)
                }
            }
            .frame(width: size, height: size)
    }
}

#if DEBUG
    #Preview("Symbol and layered crest") {
        HStack(spacing: 24) {
            BrowserSpaceSymbolArtworkContent(
                space: BrowserSpaceBrandingPreviewFixture.simpleSpace, size: 64, lockSize: 18)
            BrowserSpaceSymbolArtworkContent(
                space: BrowserSpaceBrandingPreviewFixture.crestSpace, size: 96, lockSize: 24)
        }.padding()
    }
#endif
