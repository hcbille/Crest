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

    private var availableSpaces: [SpaceModel] {
        browser.spaceModels.filter { !browser.isDeleting($0.id) }
    }

    private var resolvedSelectedSpaceID: UUID {
        BrowserLinkSettingsSpacePolicy.resolvedExternalSpaceID(
            preferredSpaceID: browser.selectedSpaceID,
            spaces: availableSpaces,
            selectedSpaceID: browser.selectedSpaceID
        )
    }

    /// The locked Spaces some route opens links in: while one is locked, the
    /// routes stay hidden, since their patterns name the sites it is used for.
    private var lockedRouteDestinationSpaces: [SpaceModel] {
        let destinationIDs = Set(links.preferences.routes.map(\.destinationSpaceID))
        return browser.spaceModels.filter { destinationIDs.contains($0.id) && spaceAccess.isLocked($0) }
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

    private var externalSpaceBinding: Binding<UUID?> {
        Binding {
            BrowserLinkSettingsSpacePolicy.resolvedExternalSpaceID(
                preferredSpaceID: links.preferences.destinationSpaceID,
                spaces: availableSpaces,
                selectedSpaceID: browser.selectedSpaceID
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
