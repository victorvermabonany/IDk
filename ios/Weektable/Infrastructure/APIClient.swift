import Foundation

struct APIErrorEnvelope: Decodable {
    struct Detail: Decodable {
        let code: String
        let message: String
    }
    let error: Detail
}

enum APIError: LocalizedError {
    case invalidResponse
    case server(status: Int, message: String)
    case configuration(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The server returned an unreadable response."
        case let .server(_, message): message
        case let .configuration(message): message
        }
    }
}

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let sessionToken: @Sendable () async -> String?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        session: URLSession = .shared,
        sessionToken: @escaping @Sendable () async -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.sessionToken = sessionToken
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func send<Response: Decodable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        idempotencyKey: String? = nil
    ) async throws -> Response {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(DeviceIdentifier.value, forHTTPHeaderField: "X-Cove-Device-ID")
        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let idempotencyKey {
            request.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key")
        }
        if let token = await sessionToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let mayRetry = method == "GET" || method == "PATCH" || idempotencyKey != nil
        for attempt in 0...1 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
                if (200..<300).contains(http.statusCode) {
                    return try decoder.decode(Response.self, from: data)
                }
                if attempt == 0, mayRetry, [408, 429, 500, 502, 503, 504].contains(http.statusCode) {
                    let retrySeconds = min(2.0, Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 0.5)
                    try await Task.sleep(for: .seconds(retrySeconds))
                    continue
                }
                let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data)
                throw APIError.server(status: http.statusCode, message: envelope?.error.message ?? "Request failed.")
            } catch {
                if Task.isCancelled { throw CancellationError() }
                if attempt == 0, mayRetry, error is URLError {
                    try await Task.sleep(for: .milliseconds(500))
                    continue
                }
                throw error
            }
        }
        throw APIError.invalidResponse
    }

    func sendEmpty(
        _ path: String,
        method: String,
        body: any Encodable
    ) async throws {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.httpBody = try encoder.encode(AnyEncodable(body))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(DeviceIdentifier.value, forHTTPHeaderField: "X-Cove-Device-ID")
        if let token = await sessionToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data)
            throw APIError.server(status: http.statusCode, message: envelope?.error.message ?? "Request failed.")
        }
    }
}

private enum DeviceIdentifier {
    static let value: String = {
        let key = "cove.device-id"
        if let legacy = UserDefaults.standard.string(forKey: "weektable.device-id") {
            UserDefaults.standard.set(legacy, forKey: key)
            return legacy
        }
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: key)
        return created
    }()
}

private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ value: any Encodable) {
        encodeClosure = { encoder in try value.encode(to: encoder) }
    }
    func encode(to encoder: Encoder) throws { try encodeClosure(encoder) }
}
