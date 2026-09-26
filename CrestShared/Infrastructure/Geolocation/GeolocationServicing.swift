@MainActor
protocol BrowserGeolocationServicing: AnyObject {
    func currentAuthorization() -> BrowserGeolocationSystemAuthorization
    func requestAuthorization() async -> BrowserGeolocationSystemAuthorization
    func requestCurrentPosition(
        identifier: String,
        options: BrowserGeolocationRequestOptions,
        receive: @escaping @MainActor (Result<BrowserGeolocationPosition, BrowserGeolocationError>) -> Void
    )
    func startWatchingPosition(
        identifier: String,
        options: BrowserGeolocationRequestOptions,
        receive: @escaping @MainActor (Result<BrowserGeolocationPosition, BrowserGeolocationError>) -> Void
    )
    func cancel(identifier: String)
    func cancelAll()
}

extension BrowserGeolocationServicing {
    /// Whether the system lets Crest use the person's location, asking them
    /// when it has not decided and trying `recover` when it refused.
    func systemAuthorizes(recovering recover: @MainActor () async -> Void) async -> Bool {
        switch currentAuthorization() {
        case .authorized:
            return true
        case .denied:
            await recover()
            return currentAuthorization() == .authorized
        case .notDetermined:
            return await requestAuthorization() == .authorized
        }
    }
}
