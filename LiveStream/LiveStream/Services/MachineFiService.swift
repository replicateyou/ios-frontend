import Foundation

struct MachineFiResult: Codable {
    let triggered: Bool
    let explanation: String
    let latencyMs: Int

    enum CodingKeys: String, CodingKey {
        case triggered
        case explanation
        case latencyMs = "latency_ms"
    }
}

@MainActor
class MachineFiService: ObservableObject {
    static let shared = MachineFiService()

    @Published var lastResult: MachineFiResult?
    @Published var isChecking = false
    @Published var errorMessage: String?

    /// Check a condition against the live HLS stream for a given streamId.
    /// The streamId's HLS URL is rewritten to use the public backend URL so MachineFi can reach it.
    func checkStream(streamId: String, condition: String) async {
        let localUrl = APIClient.shared.hlsUrl(for: streamId).absoluteString
        let publicUrl = localUrl.replacingOccurrences(
            of: Constants.backendBaseUrl,
            with: Constants.backendBaseUrl
        )

        isChecking = true
        errorMessage = nil
        defer { isChecking = false }

        do {
            var req = URLRequest(url: URL(string: "\(Constants.backendBaseUrl)/api/verify/check")!)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode([
                "stream_url": publicUrl,
                "condition": condition,
            ])
            req.timeoutInterval = 30
            let (data, _) = try await URLSession.shared.data(for: req)
            lastResult = try JSONDecoder().decode(MachineFiResult.self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
