import Foundation

/// Explicit source-language choices, held in the core's app preferences. The
/// core decides which rule applies, which target it yields and how an edit
/// replaces region aliases; rules the core refuses never translate.
struct BrowserAutomaticTranslationRules: Codable, Equatable, Sendable {
    struct Rule: Codable, Equatable, Sendable {
        var targetID: String
        var isEnabled: Bool
    }

    private(set) var sources: [String: Rule] = [:]

    init(rawValue: String = "") {
        self =
            rawValue.data(using: .utf8).flatMap {
                try? JSONDecoder().decode(Self.self, from: $0)
            } ?? Self(sources: [:])
    }

    private init(sources: [String: Rule]) { self.sources = sources }

    /// TRANSITIONAL until S6.7 retires the Swift session copy: the rules the
    /// core publishes.
    init(core rules: [TranslationRule]) {
        self.init(
            sources: Dictionary(
                rules.map { ($0.sourceLanguage, Rule(targetID: $0.targetID, isEnabled: $0.isEnabled)) },
                uniquingKeysWith: { _, last in last }))
    }

    var rawValue: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    func rule(for sourceID: String) -> Rule? {
        decision(for: sourceID)?.rule.map { Rule(targetID: $0.targetID, isEnabled: $0.isEnabled) }
    }

    func target(for sourceID: String) -> String? {
        decision(for: sourceID)?.target
    }

    static func matches(_ lhs: String, _ rhs: String) -> Bool {
        matches(lhs, in: [rhs]).first ?? false
    }

    /// `matches(language, candidate)` for each candidate, in one core call.
    static func matches(_ language: String, in candidates: [String]) -> [Bool] {
        (try? CrestCore.answer(LanguagesMatching(language: language, candidates: candidates)))?.matches
            ?? Array(repeating: false, count: candidates.count)
    }

    /// What the core decides for pages in `sourceID` under these rules.
    private func decision(for sourceID: String) -> TranslationDecision? {
        let rules = sources.map {
            TranslationRule(sourceLanguage: $0.key, targetID: $0.value.targetID, isEnabled: $0.value.isEnabled)
        }
        return try? CrestCore.answer(TranslationChoice(rules: rules, sourceLanguage: sourceID))
    }
}
