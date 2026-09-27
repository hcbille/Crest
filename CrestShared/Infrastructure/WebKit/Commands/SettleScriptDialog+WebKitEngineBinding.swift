import Foundation

extension SettleScriptDialog {
    @MainActor func perform(on binding: WebKitEngineBinding) {
        guard case .scriptDialog(_, let answer)? = binding.prompts.removeValue(forKey: promptID) else { return }
        answer(accepted, text)
    }
}
