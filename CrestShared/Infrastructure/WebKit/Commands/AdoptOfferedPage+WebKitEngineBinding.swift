import Foundation

extension AdoptOfferedPage {
    /// WebKit hands Crest its popups while it waits and offers no page.
    @MainActor func perform(on binding: WebKitEngineBinding) {
        binding.report(PageCreationFailed(pageID: pageID))
    }
}
