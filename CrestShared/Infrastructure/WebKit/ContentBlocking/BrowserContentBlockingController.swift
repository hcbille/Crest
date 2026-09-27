import Observation
import WebKit

/// Prepares rule lists and distinguishes protection changes from background refreshes.
@MainActor
@Observable
final class BrowserContentBlockingController {
    private(set) var errorDescription: String?
    @ObservationIgnored private(set) var balancedRuleLists: [WKContentRuleList]?
    @ObservationIgnored private let provider: any BrowserContentRuleListProviding
    @ObservationIgnored private var reconciledState: BrowserContentBlockingSessionState?

    init(provider: any BrowserContentRuleListProviding) {
        self.provider = provider
    }

    func prepare() async {
        guard balancedRuleLists == nil else { return }
        do {
            balancedRuleLists = try await provider.balancedRuleLists()
            errorDescription = nil
        } catch {
            errorDescription = error.localizedDescription
        }
    }

    func invalidateRuleLists() {
        balancedRuleLists = nil
    }

    /// Prepares the rule lists any Space of `workspace` needs, and answers
    /// what changed since the last reconciliation.
    func reconcile(in workspace: WorkspaceModel?) async -> BrowserContentBlockingUpdate {
        let state = BrowserContentBlockingSessionState(workspace: workspace)
        if state.policiesBySpaceID.values.contains(where: \.blocksContent) {
            await prepare()
        }
        let update = BrowserContentBlockingUpdate(state: state, previousState: reconciledState)
        reconciledState = state
        return update
    }

    func ruleLists(for policy: ContentBlockingPolicy) -> [WKContentRuleList] {
        policy.blocksContent ? balancedRuleLists ?? [] : []
    }
}
