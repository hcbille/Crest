import SwiftUI

struct BrowserLinkSettingsContent: View {
    let browser: BrowserStore
    let spaceAccess: BrowserSpaceAccessController

    let links: BrowserLinkPreferenceStore

    var body: some View {
        BrowserExternalLinkDestinationSection(
            destination: externalDestinationBinding,
            spaceID: externalSpaceBinding,
            spaces: availableSpaces
        )

        BrowserQuickWindowSettingsSection(
            archivePolicy: archivePolicyBinding,
            remembersSpaceBySite: rememberSpaceBinding
        )

        BrowserPeekSettingsSection(
            automaticallyOpensPeek: automaticPeekBinding,
            clickModifier: peekClickModifierBinding
        )

        if lockedRouteDestinationSpaces.isEmpty {
            BrowserLinkRoutingSection(
                routes: links.preferences.routes,
                spaces: availableSpaces,
                selectedSpaceID: resolvedSelectedSpaceID,
                updateRoute: updateRoute,
                remove: links.removeRoute,
                move: links.moveRoute,
                add: links.addRoute
            )
        } else {
            Section("Routing", systemImage: "arrow.triangle.branch") {
                Text("Unlock the private Spaces below before viewing or changing URL route patterns that target them.")
                    .crestFormFootnote()

                ForEach(lockedRouteDestinationSpaces) { space in
                    BrowserSettingsPrivateSpaceAccessRow(
                        space: space,
                        accessController: spaceAccess
                    )
                }
            }
            .containerValue(\.settingsFullWidth, true)
            .accessibilityIdentifier("settings-private-link-routes")
        }
    }

    private var availableSpaces: [BrowserSpace] {
        browser.session.spaces.filter {
            !browser.deletingSpaceIDs.contains($0.id)
        }
    }

    private var resolvedSelectedSpaceID: SpaceID {
        BrowserLinkSettingsSpacePolicy.resolvedExternalSpaceID(
            preferredSpaceID: browser.selectedSpaceID,
            spaces: browser.session.spaces,
            selectedSpaceID: browser.selectedSpaceID,
            unavailableSpaceIDs: browser.deletingSpaceIDs
        )
    }

    private var lockedRouteDestinationSpaces: [BrowserSpace] {
        BrowserSettingsPrivacyPolicy.lockedRouteDestinationSpaces(
            for: links.preferences.routes,
            in: browser.session.spaces,
            accessController: spaceAccess
        )
    }

    private var externalDestinationBinding: Binding<ExternalLinkDestination> {
        Binding {
            links.preferences.destination
        } set: { value in
            links.chooseExternalDestination(value)
        }
    }

    private var archivePolicyBinding: Binding<QuickWindowArchivePolicy> {
        Binding {
            links.preferences.archivePolicy
        } set: { value in
            links.chooseArchivePolicy(value)
        }
    }

    private var externalSpaceBinding: Binding<SpaceID?> {
        Binding {
            BrowserLinkSettingsSpacePolicy.resolvedExternalSpaceID(
                preferredSpaceID: links.preferences.destinationSpaceID,
                spaces: browser.session.spaces,
                selectedSpaceID: browser.selectedSpaceID,
                unavailableSpaceIDs: browser.deletingSpaceIDs
            )
        } set: { value in
            guard let value else { return }
            links.chooseExternalDestination(links.preferences.destination, spaceID: value)
        }
    }

    private var rememberSpaceBinding: Binding<Bool> {
        links.binding(.remembersSpaceBySite, reading: \.remembersSpaceBySite)
    }

    private var automaticPeekBinding: Binding<Bool> {
        links.binding(.opensPeekAutomatically, reading: \.opensPeekAutomatically)
    }

    private var peekClickModifierBinding: Binding<LinkPeekModifier> {
        Binding {
            links.preferences.peekModifier
        } set: { value in
            links.choosePeekModifier(value)
        }
    }

    private func updateRoute(
        _ routeID: UUID,
        _ field: BrowserLinkRouteFieldUpdate
    ) {
        links.updateRoute(routeID, field: field)
    }
}
