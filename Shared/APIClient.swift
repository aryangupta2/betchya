import Foundation

enum APIClient {
    static var baseURL: URL { AppConstants.apiBaseURL }

    enum APIError: LocalizedError {
        case badStatus(Int, String)
        case decoding
        case unreachable

        var errorDescription: String? {
            switch self {
            case .badStatus(let code, let body): return "API \(code): \(body)"
            case .decoding: return "Bad API response"
            case .unreachable: return "API unreachable — deploy Workers or set BETCHYA_API_URL"
            }
        }
    }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: value) { return date }
            let plain = ISO8601DateFormatter()
            plain.formatOptions = [.withInternetDateTime]
            if let date = plain.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date \(value)")
        }
        return d
    }()

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static func bootstrap(userId: String) async throws {
        struct Body: Encodable { let id: String }
        struct BootstrapResponse: Decodable { let id: String }
        _ = try await post(path: "/users/bootstrap", userId: userId, body: Body(id: userId)) as BootstrapResponse
    }

    static func ensureGroup(groupId: String, userId: String, nickname: String) async throws {
        do {
            try await joinGroup(groupId: groupId, userId: userId, nickname: nickname)
        } catch {
            struct CreateBody: Encodable { let id: String; let nickname: String }
            struct CreateResponse: Decodable { let id: String }
            _ = try await post(
                path: "/groups",
                userId: userId,
                body: CreateBody(id: groupId, nickname: nickname)
            ) as CreateResponse
        }
    }

    static func joinGroup(groupId: String, userId: String, nickname: String) async throws {
        struct Body: Encodable { let nickname: String }
        struct JoinResponse: Decodable { let groupId: String }
        _ = try await post(
            path: "/groups/\(groupId)/join",
            userId: userId,
            body: Body(nickname: nickname)
        ) as JoinResponse
    }

    static func listMarkets(groupId: String, userId: String) async throws -> [MarketDTO] {
        let response: MarketsResponse = try await get(path: "/groups/\(groupId)/markets", userId: userId)
        return response.markets
    }

    static func listMembers(groupId: String, userId: String) async throws -> [GroupMemberDTO] {
        let response: MembersResponse = try await get(path: "/groups/\(groupId)/members", userId: userId)
        return response.members
    }

    static func createMarket(
        groupId: String,
        userId: String,
        question: String,
        deadline: Date,
        subjectId: String?,
        showAmounts: Bool
    ) async throws -> MarketDTO {
        struct Body: Encodable {
            let question: String
            let deadline: Date
            let subjectId: String?
            let showAmounts: Bool
        }
        return try await post(
            path: "/groups/\(groupId)/markets",
            userId: userId,
            body: Body(
                question: question,
                deadline: deadline,
                subjectId: subjectId,
                showAmounts: showAmounts
            )
        )
    }

    static func getMarket(marketId: String, userId: String) async throws -> MarketDTO {
        try await get(path: "/markets/\(marketId)", userId: userId)
    }

    static func placeBet(
        marketId: String,
        userId: String,
        side: MarketSide,
        stake: Int
    ) async throws -> MarketDTO {
        struct Body: Encodable {
            let side: MarketSide
            let stake: Int
        }
        return try await post(
            path: "/markets/\(marketId)/bets",
            userId: userId,
            body: Body(side: side, stake: stake)
        )
    }

    // MARK: - HTTP

    private static func url(path: String) -> URL {
        URL(string: baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + path)!
    }

    private static func get<T: Decodable>(path: String, userId: String) async throws -> T {
        var request = URLRequest(url: url(path: path))
        request.httpMethod = "GET"
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        return try await send(request)
    }

    private static func post<Body: Encodable, T: Decodable>(
        path: String,
        userId: String,
        body: Body
    ) async throws -> T {
        var request = URLRequest(url: url(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")
        request.httpBody = try encoder.encode(body)
        return try await send(request)
    }

    private static func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.unreachable
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.unreachable }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}
