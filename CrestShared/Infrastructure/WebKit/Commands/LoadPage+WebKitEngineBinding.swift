import Foundation

extension LoadPage {
    @MainActor func perform(on binding: WebKitEngineBinding) {
        guard let address = URL(string: url) else { return }
        binding.page(pageID)?.load(address)
    }
}
