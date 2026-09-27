import Foundation

extension SettleAuthentication {
    @MainActor func perform(on binding: WebKitEngineBinding) {
        guard case .authentication(_, let answer)? = binding.prompts.removeValue(forKey: promptID) else { return }
        answer(credential)
    }
}
