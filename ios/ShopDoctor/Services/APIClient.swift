import Foundation

struct Upload {
    enum Kind: String { case menu = "menu_photos", shopfront = "shopfront_photos", financials = "financial_docs" }
    var kind: Kind
    var data: Data
    var mimeType: String
    var filename: String
}

enum APIError: LocalizedError {
    case server(Int, String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .server(let code, let message): L("Server error %lld: %@", code, message)
        case .badResponse: L("Unexpected response from the server.")
        }
    }
}

enum DoctorEvent: Decodable {
    case text(String)
    case tool(String)
    case error(String)
    case done

    private enum CodingKeys: String, CodingKey { case type, text, name, message }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "text": self = .text(try c.decode(String.self, forKey: .text))
        case "tool": self = .tool(try c.decode(String.self, forKey: .name))
        case "error": self = .error(try c.decode(String.self, forKey: .message))
        default: self = .done
        }
    }
}

struct APIClient {
    var baseURL: URL
    var language: AppLanguage = .english

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300  // photo reading and twin search can take a while
        return URLSession(configuration: config)
    }()

    // MARK: Shops

    func createShop(_ input: ShopInput, uploads: [Upload]) async throws -> ShopProfile {
        let boundary = "ShopDoctor-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }

        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"shop\"\r\n\r\n")
        body.append(try Self.encoder.encode(input))
        append("\r\n")
        for u in uploads {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(u.kind.rawValue)\"; filename=\"\(u.filename)\"\r\n")
            append("Content-Type: \(u.mimeType)\r\n\r\n")
            body.append(u.data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")

        var req = URLRequest(url: baseURL.appending(path: "v1/shops"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return try await send(req)
    }

    func updateShop(id: String, _ input: ShopInput) async throws -> ShopProfile {
        var req = URLRequest(url: baseURL.appending(path: "v1/shops/\(id)"))
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try Self.encoder.encode(input)
        return try await send(req)
    }

    func shop(id: String) async throws -> ShopProfile {
        try await send(URLRequest(url: baseURL.appending(path: "v1/shops/\(id)")))
    }

    // MARK: Diagnosis

    func diagnose(shopID: String) async throws -> Diagnosis {
        var req = URLRequest(url: baseURL.appending(path: "v1/shops/\(shopID)/diagnose"))
        req.httpMethod = "POST"
        return try await send(req)
    }

    func diagnosis(shopID: String) async throws -> Diagnosis {
        try await send(URLRequest(url: baseURL.appending(path: "v1/shops/\(shopID)/diagnosis")))
    }

    // MARK: Shop experience

    func runExperience(shopID: String, room: RoomSummary?, photos: [Shot: Data]) async throws -> ExperienceAudit {
        let boundary = "ShopDoctor-\(UUID().uuidString)"
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }
        if let room {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"room\"\r\n\r\n")
            body.append(try Self.encoder.encode(room))
            append("\r\n")
        }
        for (shot, data) in photos {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"shot_\(shot.rawValue)\"; filename=\"\(shot.rawValue).jpg\"\r\n")
            append("Content-Type: image/jpeg\r\n\r\n")
            body.append(data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")

        var req = URLRequest(url: baseURL.appending(path: "v1/shops/\(shopID)/experience"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return try await send(req)
    }

    func experience(shopID: String) async throws -> ExperienceAudit {
        try await send(URLRequest(url: baseURL.appending(path: "v1/shops/\(shopID)/experience")))
    }

    /// A sample scanned room (demo backend only), for trying the 3D view without LiDAR.
    func demoRoom() async throws -> RoomSummary {
        try await send(URLRequest(url: baseURL.appending(path: "v1/demo/room")))
    }

    struct Health: Decodable { var ok: Bool; var demoMode: Bool }

    func health() async throws -> Health {
        try await send(URLRequest(url: baseURL.appending(path: "health")))
    }

    // MARK: Doctor (server-sent events)

    func askDoctor(shopID: String, messages: [ChatMessage]) -> AsyncThrowingStream<DoctorEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var req = URLRequest(url: baseURL.appending(path: "v1/shops/\(shopID)/doctor"))
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    req.setValue(language.acceptLanguage, forHTTPHeaderField: "Accept-Language")
                    req.httpBody = try Self.encoder.encode(["messages": messages])

                    let (bytes, response) = try await Self.session.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
                    guard http.statusCode == 200 else { throw APIError.server(http.statusCode, "Doctor unavailable") }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let event = try Self.decoder.decode(DoctorEvent.self, from: Data(line.dropFirst(6).utf8))
                        continuation.yield(event)
                        if case .done = event { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Plumbing

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        var req = request
        req.setValue(language.acceptLanguage, forHTTPHeaderField: "Accept-Language")  // generated text comes back in this language
        let (data, response) = try await Self.session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"]
            throw APIError.server(http.statusCode, detail.map { "\($0)" } ?? "Request failed")
        }
        return try Self.decoder.decode(T.self, from: data)
    }
}
