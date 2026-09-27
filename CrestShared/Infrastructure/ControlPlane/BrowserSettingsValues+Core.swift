import Foundation

// TRANSITIONAL until the settings panes and page actions bind the core's
// records (`SpaceSettings`, `AppPreferences`) directly: the Swift preference
// and branding values they still edit, read from the records the core
// publishes and written back as the records a settings intent carries.

// MARK: - Reading the core's records

extension BrowserAppPreferences {
    init(core preferences: AppPreferences) {
        self.init()
        translationRules = BrowserAutomaticTranslationRules(core: preferences.translationRules)
        startupBehavior = BrowserStartupBehavior(coreTerm: preferences.startup) ?? Self.defaults.startupBehavior
        savedTabClosePolicy =
            BrowserDurableTabClosePolicy(coreTerm: preferences.savedTabClose) ?? Self.defaults.savedTabClosePolicy
        offersTranslation = preferences.offersTranslation
        automaticallyTranslates = preferences.automaticallyTranslates
        checksSpelling = preferences.checksSpelling
        automaticallyEntersPictureInPicture = preferences.automaticallyEntersPictureInPicture
        savedTabFaviconReturnsToSavedURL = preferences.savedTabFaviconReturnsToSavedURL
        splitFocusFollowsMouse = preferences.splitFocusFollowsMouse
    }
}

extension BrowserSpaceBrandColor {
    init(core color: BrandColor) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }
}

extension BrowserSpaceBranding {
    /// The render adapter over a look the core resolved, such as
    /// `SpaceSettings.look`, in the vocabulary the views draw. The core has
    /// already put its strengths in today's units.
    init(look branding: SpaceBranding) {
        self.init(
            colors: branding.colors.colors.map(BrowserSpaceBrandColor.init(core:)),
            bannerPattern: BrowserSpaceBannerPattern(coreTerm: branding.bannerPattern) ?? .solid,
            bannerStrength: branding.bannerStrength,
            readabilityFade: branding.readabilityFade,
            themeMode: BrowserSpaceThemeMode(coreTerm: branding.themeMode) ?? .banner,
            gradientAngle: branding.gradientAngle, showsTexture: branding.showsTexture,
            iconStyle: BrowserSpaceIconStyle(coreTerm: branding.iconStyle) ?? .simpleSymbol,
            symbolColor: branding.symbolColor.map(BrowserSpaceBrandColor.init(core:)),
            crest: BrowserSpaceCrest(core: branding.crest), folderColorIntensity: branding.folderColorIntensity,
            textColorMode: BrowserSpaceTextColorMode(coreTerm: branding.textColorMode) ?? .automatic,
            hasCustomAppearance: branding.hasCustomAppearance)
    }
}

extension BrowserSpaceCrest {
    init(core crest: SpaceCrest) {
        self.init(
            backplate: BrowserSpaceCrestBackplate(coreTerm: crest.backplate) ?? .shield,
            fieldDivision: BrowserSpaceCrestFieldDivision(coreTerm: crest.fieldDivision) ?? .plain,
            ordinary: BrowserSpaceCrestOrdinary(coreTerm: crest.ordinary) ?? BrowserSpaceCrestOrdinary.none,
            trim: BrowserSpaceCrestTrim(coreTerm: crest.trim) ?? BrowserSpaceCrestTrim.none,
            symbol: BrowserSpaceCrestSymbol(coreTerm: crest.symbol) ?? .fallback,
            chargeLayout: BrowserSpaceCrestChargeLayout(coreTerm: crest.chargeLayout) ?? .single,
            backplateColorIndex: crest.backplateColorIndex, secondaryFieldColorIndex: crest.secondaryFieldColorIndex,
            ordinaryColorIndex: crest.ordinaryColorIndex, trimColorIndex: crest.trimColorIndex,
            symbolColorIndex: crest.symbolColorIndex, edgeColorIndex: crest.edgeColorIndex,
            palette: crest.palette.map { $0.colors.map(BrowserSpaceBrandColor.init(core:)) },
            charge: crest.charge.map(BrowserSpaceCrestCharge.init(core:)), plateScale: crest.plateScale,
            edgeWidth: crest.edgeWidth, divisionCount: crest.divisionCount,
            finish: BrowserSpaceCrestFinish(coreTerm: crest.finish) ?? .flat, ordinaryWidth: crest.ordinaryWidth,
            trimWeight: crest.trimWeight, trimDetail: crest.trimDetail, chargeScale: crest.chargeScale,
            chargeOffset: crest.chargeOffset,
            chargeWeight: BrowserSpaceCrestChargeWeight(coreTerm: crest.chargeWeight) ?? .bold,
            startingPresetID: crest.startingPresetID, sheenAngle: crest.sheenAngle, sealTeeth: crest.sealTeeth,
            showsOutline: crest.showsOutline,
            depth: BrowserSpaceCrestDepth(coreTerm: crest.depth) ?? BrowserSpaceCrestDepth.none)
    }
}

extension BrowserSpaceCrestCharge {
    init(core charge: CrestCharge) {
        self =
            switch charge.kind {
            case .heraldic: .heraldic(charge.symbol.flatMap { BrowserSpaceCrestSymbol(coreTerm: $0) } ?? .fallback)
            case .system: .system(charge.text ?? "")
            case .emoji: .emoji(charge.text ?? "")
            case .monogram:
                .monogram(
                    charge.text ?? "", charge.style.flatMap { BrowserSpaceCrestMonogramStyle(coreTerm: $0) } ?? .serif)
            case .none: BrowserSpaceCrestCharge.none
            }
    }
}

extension RawRepresentable where RawValue == String {
    /// The Swift value's term for a term of the core's vocabulary. The Swift
    /// vocabularies spell each term as its stored spelling, and the generated
    /// enums name each case by that same spelling.
    init?(coreTerm term: some Sendable) {
        self.init(rawValue: String(describing: term))
    }
}

// MARK: - Writing the core's records

extension CaseIterable {
    /// The core's term for a term of a Swift vocabulary, which spells it as
    /// the core names it; nil for one the core has no name for.
    init?(swiftTerm term: some RawRepresentable<String>) {
        guard let match = Self.allCases.first(where: { String(describing: $0) == term.rawValue }) else { return nil }
        self = match
    }
}

extension BrowserSpaceBranding {
    /// This branding as a Space intent carries it, in today's units.
    var core: SpaceBranding {
        SpaceBranding(
            colors: ColorPalette(colors: colors.map(\.core)),
            bannerPattern: SpaceBannerPattern(swiftTerm: bannerPattern) ?? .solid, bannerStrength: bannerStrength,
            readabilityFade: readabilityFade, keepsControlsReadable: keepsControlsReadable,
            themeMode: SpaceThemeMode(swiftTerm: themeMode) ?? .banner, gradientAngle: gradientAngle,
            showsTexture: showsTexture, iconStyle: SpaceIconStyle(swiftTerm: iconStyle) ?? .simpleSymbol,
            symbolColor: symbolColor?.core, crest: crest.core, renderingVersion: renderingVersion,
            folderColorIntensity: folderColorIntensity,
            textColorMode: SpaceTextColorMode(swiftTerm: textColorMode) ?? .automatic,
            hasCustomAppearance: hasCustomAppearance)
    }
}

extension BrowserSpaceCrest {
    var core: SpaceCrest {
        SpaceCrest(
            backplate: CrestBackplate(swiftTerm: backplate) ?? .shield,
            fieldDivision: CrestFieldDivision(swiftTerm: fieldDivision) ?? .plain,
            ordinary: CrestOrdinary(swiftTerm: ordinary) ?? CrestOrdinary.none,
            trim: CrestTrim(swiftTerm: trim) ?? CrestTrim.none, symbol: CrestSymbol(swiftTerm: symbol) ?? .mountain,
            chargeLayout: CrestChargeLayout(swiftTerm: chargeLayout) ?? .single,
            backplateColorIndex: backplateColorIndex, secondaryFieldColorIndex: secondaryFieldColorIndex,
            ordinaryColorIndex: ordinaryColorIndex, trimColorIndex: trimColorIndex, symbolColorIndex: symbolColorIndex,
            startingPresetID: startingPresetID, edgeColorIndex: edgeColorIndex,
            palette: palette.map { ColorPalette(colors: $0.map(\.core)) }, charge: charge?.core, plateScale: plateScale,
            edgeWidth: edgeWidth, divisionCount: divisionCount, finish: CrestFinish(swiftTerm: finish) ?? .flat,
            ordinaryWidth: ordinaryWidth, trimWeight: trimWeight, trimDetail: trimDetail, chargeScale: chargeScale,
            chargeOffset: chargeOffset, chargeWeight: CrestChargeWeight(swiftTerm: chargeWeight) ?? .bold,
            sheenAngle: sheenAngle, sealTeeth: sealTeeth, showsOutline: showsOutline,
            depth: CrestDepth(swiftTerm: depth) ?? CrestDepth.none)
    }
}

extension BrowserSpaceCrestCharge {
    var core: CrestCharge {
        switch self {
        case .heraldic(let symbol):
            CrestCharge(kind: .heraldic, symbol: CrestSymbol(swiftTerm: symbol), text: nil, style: nil)
        case .system(let name): CrestCharge(kind: .system, symbol: nil, text: name, style: nil)
        case .emoji(let emoji): CrestCharge(kind: .emoji, symbol: nil, text: emoji, style: nil)
        case .monogram(let letters, let style):
            CrestCharge(kind: .monogram, symbol: nil, text: letters, style: CrestMonogramStyle(swiftTerm: style))
        case .none: CrestCharge(kind: .none, symbol: nil, text: nil, style: nil)
        }
    }
}

extension BrowserSpaceDataRetentionPreferences {
    var core: DataRetentionPreferences {
        DataRetentionPreferences(history: history, archive: archive, downloads: downloads)
    }
}

extension BrowserCredentialPreferences {
    var core: CredentialPreferences {
        CredentialPreferences(
            isEnabled: isEnabled, syncsCrestPasswordsWithICloud: syncsCrestPasswordsWithICloud,
            alsoOffersSaveToSystemPasswords: alsoOffersSaveToSystemPasswords)
    }
}

extension BrowserAppPreferences {
    /// These preferences as the core's record carries them.
    var core: AppPreferences {
        AppPreferences(
            startup: StartupBehavior(swiftTerm: startupBehavior) ?? .showStartPage,
            offersTranslation: offersTranslation, automaticallyTranslates: automaticallyTranslates,
            translationRules: translationRules.sources.keys.sorted().compactMap { source in
                translationRules.sources[source].map {
                    TranslationRule(sourceLanguage: source, targetID: $0.targetID, isEnabled: $0.isEnabled)
                }
            },
            checksSpelling: checksSpelling, automaticallyEntersPictureInPicture: automaticallyEntersPictureInPicture,
            savedTabClose: SavedTabClosePolicy(swiftTerm: savedTabClosePolicy) ?? .resumeLastLocation,
            savedTabFaviconReturnsToSavedURL: savedTabFaviconReturnsToSavedURL,
            splitFocusFollowsMouse: splitFocusFollowsMouse)
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
