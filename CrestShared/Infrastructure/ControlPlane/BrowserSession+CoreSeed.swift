import Foundation

// TRANSITIONAL until the tests, previews and fixtures that still build the
// session copy's values build `SessionState.Seed` themselves, and this file
// goes with the copy: the seed a copy value stands for, its fields alone, as a
// platform sends a session to the core. The images its tabs wear stay with
// the platform; `FaviconAssets.Offer(placedFrom:)` reads them.

// MARK: - Session

extension BrowserSession {
    /// The seed this session stands for.
    var seed: SessionState.Seed {
        SessionState.Seed(
            spaces: spaces.map(\.seed), defaultSpaceID: defaultSpaceID, disposableSeedMarker: disposableSeedMarker,
            spaceDeletions: (spaceDeletions ?? []).map {
                SpaceDeletionState(id: $0.operationID, spaceID: $0.spaceID, profileID: $0.profileID)
            },
            appPreferences: appPreferences?.core)
    }
}

// MARK: - Spaces

extension BrowserSpace {
    /// The seed this Space stands for.
    var seed: SpaceState.Seed {
        SpaceState.Seed(
            id: id, profileID: profile.id,
            settings: SpaceSettings.Seed(
                name: name, symbol: symbol, accent: accent, branding: branding.core,
                browsingPreferences: browsingPreferences.core, credentialPreferences: credentialPreferences.core,
                accessPolicy: accessPolicy.requiresAuthentication ? .deviceOwnerAuthentication : .open,
                isSavedTabsExpanded: isSavedTabsExpanded, savedTabsExpansionModifiedAt: savedTabsExpansionModifiedAt),
            folders: folders.map(\.seed), tabs: tabs.map(\.seed), splitGroups: splitGroups.map(\.seed),
            archivedTabs: archivedTabs.map {
                ArchivedTabState.Seed(tab: $0.tab.seed, archivedAt: $0.archivedAt, reason: $0.reason)
            },
            history: history.map {
                HistoryEntryState(
                    id: $0.id, url: $0.url.absoluteString, title: $0.title, firstVisitedAt: $0.firstVisitedAt,
                    lastVisitedAt: $0.lastVisitedAt, visitCount: $0.visitCount)
            })
    }
}

extension BrowserSpaceBrowsingPreferences {
    /// These preferences as the core keeps them.
    var core: BrowsingPreferences {
        let selection = searchProvider.selection
        return BrowsingPreferences(
            selectedBuiltInEngine: selection.builtIn, selectedCustomEngineID: selection.customEngineID,
            customSearchProviders: customSearchProviders.map {
                CustomSearchProvider(
                    id: $0.id, name: $0.name, searchURLTemplate: $0.searchURLTemplate,
                    suggestionURLTemplate: $0.suggestionURLTemplate)
            },
            searchSuggestionsEnabled: searchSuggestionsEnabled, currentTabCleanup: currentTabCleanupPolicy,
            contentBlocking: contentBlockingPolicy, dataRetention: dataRetention.core)
    }
}

// MARK: - Folders, tabs and splits

extension BrowserFolder {
    /// The seed this folder stands for.
    var seed: FolderState.Seed {
        FolderState.Seed(
            id: id, location: TabPlacement.named(location.rawValue) ?? .saved, title: title, symbol: symbol,
            color: color.core,
            parentID: parentID, isCollapsed: isCollapsed, collapseModifiedAt: collapseModifiedAt,
            orderAnchorTabID: orderAnchorTabID)
    }
}

extension BrowserTab {
    /// The seed this tab stands for, without the image it wears.
    var seed: TabState.Seed {
        TabState.Seed(
            id: id, title: title, url: url?.absoluteString,
            nativeContent: nativeContent.map { NativeTabContent(kind: $0.kind, resourceID: $0.resourceID) },
            savedURL: savedURL?.absoluteString, symbol: symbol, faviconURL: faviconURL?.absoluteString,
            iconAccent: iconAccent.map { TabIconAccent(red: $0.red, green: $0.green, blue: $0.blue) },
            storedIconMode: storedIconMode, placement: placement, folderID: folderID, splitGroupID: splitGroupID,
            lastActivatedAt: lastActivatedAt, positionModifiedAt: positionModifiedAt, customTitle: customTitle,
            titleModifiedAt: titleModifiedAt, keepsPageLoaded: keepsPageLoaded)
    }
}

extension BrowserSplitGroupMetadata {
    /// The seed this split stands for.
    var seed: SplitGroupState.Seed {
        SplitGroupState.Seed(
            id: id, customTitle: customTitle, titleModifiedAt: titleModifiedAt, customIconSymbol: customIconSymbol,
            iconModifiedAt: iconModifiedAt, tint: tint?.core, tintModifiedAt: tintModifiedAt)
    }
}
