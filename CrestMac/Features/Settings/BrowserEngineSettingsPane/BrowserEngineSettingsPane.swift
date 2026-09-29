import SwiftUI

/// Device-wide routing choices, including choices made through a page's menu.
/// Changing a choice affects future pages and navigations, leaving open pages
/// on their current engine until the person chooses to move them.
struct BrowserEngineSettingsPane: View {
    // MARK: - Variables

    let core: CrestCore
    @State private var editing: BrowserEngineRuleDraft?
    @State private var failure: String?

    private var preferences: EnginePreferences { core.state.enginePreferences }
    private var availableEngines: [EngineKind] { core.state.engines?.engines.map(\.kind) ?? [] }
    private var defaultEngine: EngineKind {
        core.state.engines?.engines.first(where: \.isDefault)?.kind ?? BrowserEngineRegistration.current.kind
    }

    // MARK: - Actions - Presentation

    var body: some View {
        BrowserSettingsPane(.engines) {
            ForEach(BrowserEngineOption.all) { option in
                Section {
                    BrowserEngineOptionCard(
                        option: option, isSelected: defaultEngine == option.engine,
                        isRecommended: BrowserEngineRegistration.current.kind == option.engine,
                        isAvailable: availableEngines.contains(option.engine)
                    ) { selectDefault(option.engine) }
                }
            }
            Section {
                CrestFormFootnote(
                    "Website rules override your default. Links opened by a page stay on that page’s engine. Existing pages keep their engine."
                )
                if availableEngines.contains(.chromium) {
                    CrestFormFootnote(
                        "A WebKit-only session leaves Chromium unloaded. Opening a Chromium website or extension loads it for the rest of the session."
                    )
                }
                Button("Use Recommended Default") { selectDefault(nil) }
                    .disabled(preferences.defaultEngine == nil)
            }
            .containerValue(\.settingsFullWidth, true)
            Section("Website rules", systemImage: "globe") {
                if preferences.rules.isEmpty {
                    Text("No website rules. Websites use your default engine.")
                        .foregroundStyle(.secondary)
                }
                ForEach(preferences.rules.sorted { $0.origin.displayName < $1.origin.displayName }, id: \.origin) {
                    rule in
                    HStack {
                        Button {
                            editing = BrowserEngineRuleDraft(rule: rule)
                        } label: {
                            HStack {
                                Text(rule.origin.displayName)
                                Spacer()
                                Text(rule.engine.title).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit \(rule.origin.displayName), \(String(localized: rule.engine.title))")
                        Button("Remove Rule", systemImage: "minus.circle") { remove(rule) }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .help("Return this website to the default engine")
                    }
                }
                Button("Add Website Rule…", systemImage: "plus") {
                    editing = BrowserEngineRuleDraft(engine: defaultEngine)
                }
                .accessibilityIdentifier("add-engine-rule")
                CrestFormFootnote(
                    "Rules match the website’s scheme, host, and port. A rule for example.com does not include its subdomains. Choices made in a page’s menu and protected-video fallback appear here. Private-page choices stay private."
                )
            }
            .containerValue(\.settingsFullWidth, true)
            if let failure { Text(failure).foregroundStyle(.red) }
        }
        .sheet(item: $editing) { draft in
            BrowserEngineRuleEditor(core: core, draft: draft, availableEngines: availableEngines)
        }
    }

    // MARK: - Actions - Preferences

    private func selectDefault(_ engine: EngineKind?) {
        do {
            try core.send(SelectDefaultEngine(engine: engine))
            failure = nil
        } catch { failure = error.explanation }
    }

    private func remove(_ rule: SiteEngineRule) {
        do {
            try core.send(ForgetEngineRule(origin: rule.origin))
            failure = nil
        } catch { failure = error.explanation }
    }
}
