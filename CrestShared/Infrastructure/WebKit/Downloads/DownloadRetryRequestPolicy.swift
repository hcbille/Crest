import Foundation

/// The request a retry of a blocked download replays.
enum BrowserDownloadRetryRequestPolicy {
    nonisolated static func replayableRequest(
        from original: URLRequest
    ) -> URLRequest? {
        guard let url = original.url,
            ["http", "https"].contains(url.scheme?.lowercased()),
            original.httpBodyStream == nil
        else { return nil }

        // WKDownload.originalRequest contains WebKit-private, one-shot request
        // properties. Reusing that object after returning nil from the first
        // destination decision makes WebKit cancel the replacement before its
        // delegate can choose a destination. Rebuild only the public network
        // contract needed to replay the request in the same WKWebView session.
        var request = URLRequest(
            url: url,
            cachePolicy: original.cachePolicy,
            timeoutInterval: original.timeoutInterval
        )
        request.httpMethod = original.httpMethod
        request.allHTTPHeaderFields = original.allHTTPHeaderFields
        request.httpBody = original.httpBody
        request.mainDocumentURL = original.mainDocumentURL
        request.httpShouldHandleCookies = original.httpShouldHandleCookies
        request.networkServiceType = original.networkServiceType
        request.allowsCellularAccess = original.allowsCellularAccess
        return request
    }
}
