import SwiftUI

struct BrowserSidebarBackgroundInteractionView: View {
    let editSpace: () -> Void
    let createSpace: (() -> Void)?

    var body: some View {
        // Dragging the empty sidebar moves the window. Its double-click opens a
        // new tab (`BrowserSidebarEmptySpaceNewTabGesture`) rather than acting
        // as the title bar, as it has since Crest offered it.
        Color.clear
            .contentShape(.rect)
            .gesture(WindowDragGesture())
            .allowsWindowActivationEvents()
            .contextMenu {
                ForEach(
                    BrowserSidebarBackgroundInteractionPolicy.actions.filter { $0 != .newSpace || createSpace != nil },
                    id: \.self
                ) { action in
                    Button(action.title, systemImage: action.systemImage) {
                        perform(action)
                    }
                }
                .crestMenuActionLabelStyle()
            }
            .accessibilityLabel("Sidebar background")
            .accessibilityHint("Drag to move the window or open Space actions")
    }

    private func perform(_ action: BrowserSidebarBackgroundAction) {
        switch action {
        case .editSpace:
            editSpace()
        case .newSpace:
            createSpace?()
        }
    }
}
