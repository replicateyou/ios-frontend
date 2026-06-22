import Foundation

// MARK: - Response types

struct StartStreamResponse: Codable {
    let streamId: String
}

struct EndStreamResponse: Codable {
    let rootHash: String
}

// MARK: - APIClient

/// Handles all backend communication.
/// Currently returns mock data — swap `useMocks = false` once the backend is running.
@MainActor
class APIClient: ObservableObject {
    static let shared = APIClient()

    private let useMocks = false
    private let baseUrl = Constants.backendBaseUrl

    // MARK: - Stream lifecycle

    func startStream(title: String, creatorAddress: String) async throws -> String {
        if useMocks {
            try await Task.sleep(nanoseconds: 500_000_000)
            return "stream-\(UUID().uuidString.prefix(8).lowercased())"
        }
        var req = URLRequest(url: URL(string: "\(baseUrl)/api/streams/start")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["title": title, "creatorAddress": creatorAddress])
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(StartStreamResponse.self, from: data).streamId
    }

    func uploadSegment(streamId: String, segmentData: Data, segmentIndex: Int, duration: Double) async throws {
        if useMocks { return }
        let boundary = UUID().uuidString
        var req = URLRequest(url: URL(string: "\(baseUrl)/api/streams/\(streamId)/segment")!)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"segment\"; filename=\"segment_\(segmentIndex).mp4\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: video/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(segmentData)
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"duration\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(duration)".data(using: .utf8)!)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        _ = try await URLSession.shared.data(for: req)
    }

    func endStream(streamId: String) async throws -> String {
        if useMocks {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return "0x\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
        }
        var req = URLRequest(url: URL(string: "\(baseUrl)/api/streams/\(streamId)/end")!)
        req.httpMethod = "POST"
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(EndStreamResponse.self, from: data).rootHash
    }

    // MARK: - Feed

    func getStreams() async throws -> [Stream] {
        if useMocks {
            try await Task.sleep(nanoseconds: 300_000_000)
            return Stream.mocks
        }
        let (data, _) = try await URLSession.shared.data(from: URL(string: "\(baseUrl)/api/streams")!)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Stream].self, from: data)
    }

    // MARK: - URLs

    func hlsUrl(for streamId: String) -> URL {
        URL(string: "\(baseUrl)/api/streams/\(streamId)/live.m3u8")!
    }

    func publicHlsUrl(for streamId: String) -> URL {
        URL(string: "\(Constants.streamingUrl)/api/streams/\(streamId)/live.m3u8")!
    }

    func archivedUrl(for streamId: String) -> URL {
        URL(string: "\(baseUrl)/api/streams/\(streamId)/archived")!
    }

    // MARK: - Markets

    func createMarket(streamUrl: String, condition: String, title: String? = nil, initialLiquidityWei: String? = nil) async throws {
        if useMocks { return }
        var req = URLRequest(url: URL(string: "\(baseUrl)/v1/stream/mock")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "stream_url": streamUrl,
            "condition": condition
        ]
        if let title { body["title"] = title }
        if let initialLiquidityWei { body["initial_liquidity_wei"] = initialLiquidityWei }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[API] POST /v1/stream")
        print("[API] URL: \(req.url?.absoluteString ?? "unknown")")
        print("[API] Body: \(body)")

        let (data, response) = try await URLSession.shared.data(for: req)
        if let httpResponse = response as? HTTPURLResponse {
            print("[API] Status: \(httpResponse.statusCode)")
        }
        if let responseStr = String(data: data, encoding: .utf8) {
            print("[API] Response: \(responseStr)")
        }
    }
}
