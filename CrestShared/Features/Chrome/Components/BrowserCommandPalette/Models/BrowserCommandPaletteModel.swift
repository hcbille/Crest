import Foundation
import Observation

/// The shared palette's rows and keyboard selection. The core ranks what the
/// palette offers for each query, off the main thread; an answer that arrives
/// after a newer keystroke is dropped, so the latest query always wins. The
/// query text, the selection and the completion editing stay here.
@MainActor
@Observable
final class BrowserCommandPaletteModel {
    // MARK: - Variables

    /// The window the palette speaks for, whose core answers it.
    let browser: BrowserStore
    /// The Space the palette speaks for, or nil when the window shows none.
    let space: SpaceModel?
    let selectedTabID: UUID?
    let commands: BrowserCommandPaletteCommandRegistry?
    /// Whether the palette offers the platform's resting commands before
    /// anything is typed. The Start Page's palette offers commands only once
    /// what is typed matches one.
    let offersRestingCommands: Bool

    var query: String {
        didSet {
            guard query != oldValue else { return }
            selectedResultIndex = 0
            requestAnswer()
        }
    }

    private(set) var groups: [BrowserCommandPaletteGroup] = []
    /// Every row, in the order the keyboard steps through them.
    private(set) var items: [BrowserCommandPaletteItem] = []
    private(set) var selectedResultIndex = 0
    private(set) var keyboardSelectionRevision = 0
    private(set) var completionEditing = BrowserURLCompletionEditingState()
    private var completionProposal: AddressCompletion?
    @ObservationIgnored var applyCompletion: ((String, NSRange) -> Void)?

    var urlCompletion: AddressCompletion? {
        guard isCompletionSourceAvailable, completionEditing.canPropose(for: query),
            completionProposal?.typed == query
        else { return nil }
        return completionProposal
    }

    var isCompletionSourceAvailable: Bool {
        if selectedTabID != nil { return availableSourceAssignment != nil }
        guard let space, let actions = emptySelectionActions,
            actions.source == BrowserSpaceRuntimeAssignment(spaceID: space.id, profileID: space.profileID)
        else { return false }
        return actions.isAvailable
    }

    /// Counts keystrokes: each query asks under the next number, and only the
    /// answer to the latest is shown.
    @ObservationIgnored private var sequence = 0
    /// The keystroke whose answer the rows show.
    @ObservationIgnored private var shownSequence = 0
    @ObservationIgnored private var answerTask: Task<Void, Never>?

    private let suggestionDebounce: Duration
    private let fetchSuggestions: @Sendable (URL) async throws -> [String]
    private let isSourceAvailableAction: (BrowserTabRuntimeAssignment) -> Bool
    private let selectTabAction: (BrowserTabRuntimeAssignment, BrowserTabRuntimeAssignment) -> Bool
    private let openURLAction: (BrowserTabRuntimeAssignment, URL) -> Bool
    private let dismissAction: () -> Void
    private let emptySelectionActions: BrowserEmptySelectionPaletteActions?

    private var availableSourceAssignment: BrowserTabRuntimeAssignment? {
        guard let sourceAssignment, isSourceAvailableAction(sourceAssignment) else { return nil }
        return sourceAssignment
    }

    private var sourceAssignment: BrowserTabRuntimeAssignment? {
        guard let space, let selectedTabID else { return nil }
        return BrowserTabRuntimeAssignment(tabID: selectedTabID, spaceID: space.id, profileID: space.profileID)
    }

    // MARK: - Initializers

    init(
        browser: BrowserStore,
        space: SpaceModel?,
        selectedTabID: UUID?,
        initialQuery: String,
        commands: BrowserCommandPaletteCommandRegistry?,
        offersRestingCommands: Bool = true,
        suggestionDebounce: Duration = .milliseconds(250),
        fetchSuggestions: @escaping @Sendable (URL) async throws -> [String] = { address in
            try await BrowserSearchSuggestionClient.shared.suggestions(from: address)
        },
        isSourceAvailable: @escaping (BrowserTabRuntimeAssignment) -> Bool,
        selectTab: @escaping (BrowserTabRuntimeAssignment, BrowserTabRuntimeAssignment) -> Bool,
        openURL: @escaping (BrowserTabRuntimeAssignment, URL) -> Bool,
        dismiss: @escaping () -> Void,
        emptySelectionActions: BrowserEmptySelectionPaletteActions? = nil
    ) {
        self.browser = browser
        self.space = space
        self.selectedTabID = selectedTabID
        self.commands = commands
        self.offersRestingCommands = offersRestingCommands
        query = initialQuery
        self.suggestionDebounce = suggestionDebounce
        self.fetchSuggestions = fetchSuggestions
        isSourceAvailableAction = isSourceAvailable
        selectTabAction = selectTab
        openURLAction = openURL
        dismissAction = dismiss
        self.emptySelectionActions = emptySelectionActions
        // The palette opens with its rows: the resting answer is quick to
        // rank, so it is asked for on the main thread.
        if let answer = try? browser.core.query(question(for: initialQuery)) { show(answer, for: sequence) }
    }

    // MARK: - Actions - Completion

    func updateCompletionEditing(text: String, selection: NSRange, isComposing: Bool) {
        completionEditing.update(text: text, selection: selection, isComposing: isComposing)
        if !isComposing { query = text }
    }

    func rejectURLCompletion() { completionEditing.reject() }

    func invalidateURLCompletion() {
        completionProposal = nil
        completionEditing.reject()
    }

    @discardableResult
    func acceptURLCompletion() -> Bool {
        guard let proposal = urlCompletion, let applyCompletion else { return false }
        completionEditing.reject()
        applyCompletion(proposal.insertionText, proposal.insertionRange)
        // Return right after Tab must find the accepted address as the primary
        // action even before the off-main answer arrives.
        if query == proposal.accepted, let answer = try? browser.core.query(question(for: query)) {
            show(answer, for: sequence)
            selectedResultIndex = 0
        }
        completionEditing.reject()
        return true
    }

    // MARK: - Actions - Selection

    func moveSelection(by offset: Int) {
        rejectURLCompletion()
        guard shownSequence == sequence, !items.isEmpty else { return }
        selectedResultIndex = (selectedResultIndex + offset + items.count) % items.count
        keyboardSelectionRevision &+= 1
    }

    func selectResult(at index: Int) {
        rejectURLCompletion()
        guard shownSequence == sequence, items.indices.contains(index) else { return }
        selectedResultIndex = index
    }

    func activateSelectedResult() {
        guard items.indices.contains(selectedResultIndex) else { return }
        activate(items[selectedResultIndex].row)
    }

    func activate(_ row: PaletteRow) {
        guard shownSequence == sequence else { return }
        if selectedTabID == nil {
            guard let actions = emptySelectionActions, let space,
                actions.source == BrowserSpaceRuntimeAssignment(spaceID: space.id, profileID: space.profileID),
                actions.isAvailable
            else { return }
            let didActivate: Bool
            if let tabID = row.tabID {
                didActivate = actions.selectTab(
                    BrowserTabRuntimeAssignment(tabID: tabID, spaceID: space.id, profileID: space.profileID))
            } else if let url = row.address.flatMap(URL.init(string:)) {
                didActivate = actions.openURL(url)
            } else if let command = row.command {
                commands?.perform(command)
                didActivate = commands != nil
            } else {
                didActivate = false
            }
            if didActivate { dismiss() }
            return
        }
        guard let sourceAssignment = availableSourceAssignment else { return }
        let didActivate: Bool
        if let tabID = row.tabID {
            didActivate = selectTabAction(
                sourceAssignment,
                BrowserTabRuntimeAssignment(
                    tabID: tabID, spaceID: sourceAssignment.spaceID, profileID: sourceAssignment.profileID))
        } else if let url = row.address.flatMap(URL.init(string:)) {
            didActivate = openURLAction(sourceAssignment, url)
        } else if let command = row.command {
            commands?.perform(command)
            didActivate = commands != nil
        } else {
            didActivate = false
        }
        if didActivate { dismiss() }
    }

    func dismiss() {
        dismissAction()
    }

    func waitForPendingResults() async {
        await answerTask?.value
    }

    // MARK: - Actions - Presentation

    /// The tab a row shows, for its icon.
    func tab(for row: PaletteRow) -> TabStateModel? {
        row.tabID.flatMap { space?.tabs.model($0) }
    }

    /// The engine a row's tab runs on, when its icon wears that engine's
    /// badge, for what the row says to VoiceOver.
    func engineBadge(for row: PaletteRow) -> EngineKind? {
        row.tabID.flatMap(browser.core.state.engineBadge(forTab:))
    }

    /// The search engine a row searches with, for its icon.
    func searchProvider(for row: PaletteRow) -> SearchProvider? {
        space?.settings.browsingPreferences.searchProvider(builtIn: row.engine, customID: row.customEngineID)
            ?? row.engine.flatMap { SearchProvider.named($0.name) }
    }

    // MARK: - Actions - Answers

    /// The question for `text`, with the commands this window offers and the
    /// suggestions fetched for the same text.
    private func question(for text: String, remote: [String] = []) -> PaletteSuggestions {
        PaletteSuggestions(windowID: browser.windowID, text: text, commands: offeredCommands(for: text), remote: remote)
    }

    /// The commands the core may rank for `text`. A palette without resting
    /// commands offers none while the text is blank, which the core reads as
    /// nothing typed.
    private func offeredCommands(for text: String) -> [PaletteCommand] {
        guard offersRestingCommands || !text.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return commands?.paletteCommands ?? []
    }

    /// Asks the core for the current query's answer off the main thread, then
    /// for the search suggestions the answer allows, and shows each only while
    /// no later keystroke has asked again.
    private func requestAnswer() {
        sequence &+= 1
        let asked = sequence
        let question = question(for: query)
        let core = browser.core
        answerTask?.cancel()
        answerTask = Task { [weak self] in
            guard let answer = await Self.answer(question, from: core), !Task.isCancelled, let self,
                asked == sequence
            else { return }
            show(answer, for: asked)
            guard let address = answer.suggestionAddress.flatMap(URL.init(string:)) else { return }
            do {
                try await Task.sleep(for: suggestionDebounce)
                let fetched = try await fetchSuggestions(address)
                try Task.checkCancellation()
                guard asked == sequence, !fetched.isEmpty,
                    let merged = await Self.answer(
                        PaletteSuggestions(
                            windowID: question.windowID, text: question.text, commands: question.commands,
                            remote: fetched),
                        from: core),
                    asked == sequence
                else { return }
                let selected = items.indices.contains(selectedResultIndex) ? items[selectedResultIndex].id : nil
                show(merged, for: asked)
                if let selected, let index = items.firstIndex(where: { $0.id == selected }) {
                    selectedResultIndex = index
                }
            } catch {
                // The local rows are already shown. Cancellation, a failed
                // fetch or an unreadable response leave them as they are.
            }
        }
    }

    private func show(_ answer: PaletteAnswer, for asked: Int) {
        shownSequence = asked
        groups = BrowserCommandPaletteGroup.groups(of: answer)
        items = groups.flatMap(\.items)
        completionProposal = answer.completion
        if !items.indices.contains(selectedResultIndex) { selectedResultIndex = 0 }
    }

    /// The core's answer, ranked on a background thread.
    private nonisolated static func answer(_ question: PaletteSuggestions, from core: CrestCore) async -> PaletteAnswer?
    {
        await Task.detached(priority: .userInitiated) { try? core.query(question) }.value
    }
}

enum BrowserSearchSuggestionResponseParser {
    static func suggestions(from data: Data) -> [String] {
        guard data.count <= BrowserSearchSuggestionClient.maximumResponseByteCount else {
            return []
        }
        guard
            let payload = try? JSONSerialization.jsonObject(with: data) as? [Any],
            payload.count >= 2,
            let values = payload[1] as? [Any]
        else { return [] }
        return values.compactMap { $0 as? String }.prefix(20).map { $0 }
    }
}

/// Fetches an engine's search suggestions from the address the core names,
/// without cookies or caching.
actor BrowserSearchSuggestionClient {
    static let shared = BrowserSearchSuggestionClient()
    static let maximumResponseByteCount = 64 * 1_024

    nonisolated static var sessionConfiguration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 5
        return configuration
    }

    private let session: URLSession

    init(session: URLSession? = nil) {
        self.session = session ?? URLSession(configuration: Self.sessionConfiguration)
    }

    func suggestions(from address: URL) async throws -> [String] {
        var request = URLRequest(url: address)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard
            let response = response as? HTTPURLResponse,
            (200...299).contains(response.statusCode),
            response.expectedContentLength <= 0
                || response.expectedContentLength <= Self.maximumResponseByteCount
        else { return [] }

        var data = Data()
        data.reserveCapacity(min(Self.maximumResponseByteCount, 8 * 1_024))
        for try await byte in bytes {
            guard data.count < Self.maximumResponseByteCount else { return [] }
            data.append(byte)
        }
        return BrowserSearchSuggestionResponseParser.suggestions(from: data)
    }
}
