import CrestCoreABI
import Foundation
import os

/// A stateless boundary for synchronous domain decisions. Session mutations
/// remain commands to the core session authority.
enum BrowserCorePolicy {
    // MARK: - Types

    /// Every policy request: the version and operation, then the operation's
    /// own members at the same level. The session answers some policies too,
    /// with the same request.
    struct Request<Arguments: Encodable>: Encodable {
        private enum CodingKeys: String, CodingKey {
            case version
            case operation
        }

        let operation: BrowserPolicyOperation
        let arguments: Arguments

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(1, forKey: .version)
            try container.encode(operation, forKey: .operation)
            try arguments.encode(to: encoder)
        }
    }

    // MARK: - Variables

    private static let logger = Logger(subsystem: "com.pauldavis.crest", category: "CorePolicy")

    // MARK: - Actions - Evaluation

    /// One bounded policy call. Nil when the request cannot be encoded, the core
    /// rejects it or cannot answer, or the answer does not decode; every caller
    /// maps that to its own fail-safe outcome.
    static func evaluate<Arguments: Encodable, Answer: Decodable>(
        _ operation: BrowserPolicyOperation, _ arguments: Arguments, answer: Answer.Type
    ) -> Answer? {
        guard let data = try? JSONEncoder().encode(Request(operation: operation, arguments: arguments)) else {
            return nil
        }
        guard let output = evaluate(data, operation: operation) else { return nil }
        return try? JSONDecoder().decode(Answer.self, from: output)
    }

    /// A policy call without members of its own.
    static func evaluate<Answer: Decodable>(_ operation: BrowserPolicyOperation, answer: Answer.Type) -> Answer? {
        evaluate(operation, BrowserCoreNoArguments(), answer: answer)
    }

    private static func evaluate(_ data: Data, operation: BrowserPolicyOperation) -> Data? {
        var length = 0
        let measured = data.withUnsafeBytes {
            crest_core_evaluate_policy($0.bindMemory(to: UInt8.self).baseAddress, data.count, nil, 0, &length)
        }
        guard measured == CREST_BUFFER_TOO_SMALL, length > 0, length <= 65_536 else {
            logger.error("Core policy rejected \(operation.rawValue, privacy: .public): \(measured)")
            return nil
        }
        var output = Data(count: length)
        let capacity = length
        let result = output.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { input in
                crest_core_evaluate_policy(
                    input.bindMemory(to: UInt8.self).baseAddress, data.count,
                    destination.bindMemory(to: UInt8.self).baseAddress, capacity, &length)
            }
        }
        guard result == CREST_OK else {
            logger.error("Core policy output failed: \(result)")
            return nil
        }
        return output
    }
}
