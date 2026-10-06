import Foundation

/// The Web Store download made without the engine: the request Chromium's own
/// installer sends, over a session that keeps nothing.
enum ExtensionFallbackDownload {
    struct Failure: Error {
        let reason: String
    }
    /// A guard against a runaway response, not a limit on extensions: the Web Store's packages are far
    /// smaller, and Chromium's installer judges whatever arrives.
    static let sizeCap = 2 * 1024 * 1024 * 1024

    /// Set when the download was stopped for growing past `sizeCap`.
    final class Cutoff: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        var isSet: Bool { lock.withLock { value } }
        func set() { lock.withLock { value = true } }
    }

    /// The update endpoint's address for `id`, or nil when `id` is not a
    /// 32-letter a–p extension identifier or the version cannot be sent.
    static func url(id: String, engineVersion: String) -> URL? {
        guard id.utf8.count == 32, id.utf8.allSatisfy({ (UInt8(ascii: "a")...UInt8(ascii: "p")).contains($0) }),
            let version = engineVersion.addingPercentEncoding(
                withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))),
            !version.isEmpty
        else { return nil }
        return URL(
            string:
                "https://clients2.google.com/service/update2/crx?response=redirect&os=mac&arch=arm64&prod=chromiumcrx&prodchannel=&prodversion=\(version)&lang=en-US&acceptformat=crx3,puff&x=id%3D\(id)%26installsource%3Dondemand%26uc"
        )
    }
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60 * 60
        return URLSession(configuration: configuration, delegate: HTTPSOnly(), delegateQueue: nil)
    }
    static func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpShouldHandleCookies = false
        return request
    }
    /// Judges the downloaded file and, when it is a Chrome package, moves it to
    /// a temporary file the caller owns. The system deletes `location` when
    /// the completion handler returns, so this runs inside it. A file that is
    /// not accepted is never left behind.
    static func ownedPackage(
        location: URL?, response: URLResponse?, error: Error?, oversized: Bool = false
    ) -> Result<URL, Failure> {
        if let error {
            if oversized { return .failure(Failure(reason: "package larger than \(sizeCap) bytes")) }
            let canceled = (error as? URLError)?.code == .cancelled
            return .failure(Failure(reason: canceled ? "canceled" : error.localizedDescription))
        }
        guard let http = response as? HTTPURLResponse else { return .failure(Failure(reason: "no HTTP response")) }
        guard http.url?.scheme?.lowercased() == "https" else {
            return .failure(Failure(reason: "not an https response"))
        }
        guard http.statusCode == 200 else { return .failure(Failure(reason: "HTTP status \(http.statusCode)")) }
        guard let location else { return .failure(Failure(reason: "no file")) }
        let size =
            ((try? FileManager.default.attributesOfItem(atPath: location.path)[.size]) as? NSNumber)?.intValue ?? 0
        guard size > 0, size <= sizeCap else { return .failure(Failure(reason: "unexpected size \(size)")) }
        guard hasCRX3Header(location) else { return .failure(Failure(reason: "not a Chrome extension package")) }
        let kept = FileManager.default.temporaryDirectory.appendingPathComponent(
            "crest-extension-download-\(UUID()).crx")
        do {
            try FileManager.default.moveItem(at: location, to: kept)
            return .success(kept)
        } catch {
            return .failure(Failure(reason: error.localizedDescription))
        }
    }
    /// "Cr24", then the little-endian format version 3.
    private static func hasCRX3Header(_ file: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return false }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 8), head.count == 8 else { return false }
        let bytes = Array(head)
        let version = UInt32(bytes[4]) | UInt32(bytes[5]) << 8 | UInt32(bytes[6]) << 16 | UInt32(bytes[7]) << 24
        return bytes[0..<4] == [0x43, 0x72, 0x32, 0x34] && version == 3
    }
    /// Refuses a redirect off https, so the response is judged as it stands.
    private final class HTTPSOnly: NSObject, URLSessionTaskDelegate, Sendable {
        func urlSession(
            _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
        ) {
            completionHandler(request.url?.scheme?.lowercased() == "https" ? request : nil)
        }
    }
}
