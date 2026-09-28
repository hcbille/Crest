import Foundation

extension LoadPage {
    /// A page the core asked to load the address of a window its document
    /// asked for, which the core kept in the page, loads the window's own
    /// request, as its document made it.
    @MainActor func perform(on binding: WebKitEngineBinding) {
        guard let address = URL(string: url), let page = binding.page(pageID) else { return }
        if let offer = binding.offers.values.first(where: { $0.sourcePageID == pageID && $0.request.url == address }) {
            page.load(offer.request)
        } else {
            page.load(address)
        }
    }
}
