#if CREST_CHROMIUM_HOST
    import Foundation

    /// The JavaScript dialogs the host routes to Crest's presenter.
    enum ChromiumJavaScriptDialogKind: String, Sendable {
        case alert
        case confirm
        case prompt
        case beforeUnload
    }

    /// The HTTP authentication schemes the host routes to Crest's prompt.
    enum ChromiumAuthenticationMethod: String, Decodable, Sendable {
        case basic
        case digest
    }

    /// The HTTP authentication challenge the host hands to Crest.
    struct ChromiumAuthenticationChallenge: Decodable {
        let url: String
        let host: String
        let port: Int
        let realm: String?
        let method: ChromiumAuthenticationMethod
        let isProxy: Bool?
        let previousFailureCount: Int?
    }

    /// Decodes a host payload with a wire model. Only payloads made of JSON
    /// values (strings, numbers, booleans, null, arrays and dictionaries of them)
    /// have one.
    enum ChromiumHostPayload {
        static func decode<Payload: Decodable>(_ type: Payload.Type, from values: [String: Any]) -> Payload? {
            guard JSONSerialization.isValidJSONObject(values),
                let data = try? JSONSerialization.data(withJSONObject: values)
            else { return nil }
            return try? JSONDecoder().decode(type, from: data)
        }
    }
#endif
