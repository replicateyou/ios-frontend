import Foundation

// MARK: - StreamBetClient

@MainActor
class StreamBetClient: ObservableObject {
    static let shared = StreamBetClient()

    var authToken: String?

    // TODO: Replace with your own API base URL when available
    private let base = ""
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    // MARK: - Request helpers

    private func request(_ path: String, method: String = "GET") -> URLRequest {
        var req = URLRequest(url: URL(string: "\(base)\(path)")!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, _) = try await URLSession.shared.data(for: request(path))
        return try decoder.decode(T.self, from: data)
    }

    private func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        var req = request(path, method: "POST")
        req.httpBody = try encoder.encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(Response.self, from: data)
    }

    // MARK: - Markets

    func getMarkets(status: String? = nil, limit: Int = 20, cursor: String? = nil) async throws -> PaginatedMarkets {
        var query = "?limit=\(limit)"
        if let status { query += "&status=\(status)" }
        if let cursor { query += "&cursor=\(cursor)" }
        return try await get("/markets\(query)")
    }

    func getMarketDetail(id: String) async throws -> SBMarketDetail {
        return try await get("/markets/\(id)")
    }

    func placeBet(marketId: String, side: SBBetSide, amountWei: String) async throws -> SBBetResponse {
        struct Body: Encodable { let side: SBBetSide; let amountWei: String }
        return try await post("/markets/\(marketId)/bet", body: Body(side: side, amountWei: amountWei))
    }

    // MARK: - Streams / Market creation

    func createStreamMarket(
        streamUrl: String,
        condition: String,
        title: String? = nil,
        initialLiquidityWei: String? = nil
    ) async throws -> SBStreamMarket {
        struct Body: Encodable {
            let streamUrl: String
            let condition: String
            let title: String?
            let initialLiquidityWei: String?
        }
        return try await post("/stream", body: Body(
            streamUrl: streamUrl,
            condition: condition,
            title: title,
            initialLiquidityWei: initialLiquidityWei
        ))
    }

}
