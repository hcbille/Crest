import Foundation

extension SettlePermission {
    @MainActor func perform(on binding: WebKitEngineBinding) {
        guard case .permission(_, let answer)? = binding.prompts.removeValue(forKey: promptID) else { return }
        answer(grants)
    }
}
