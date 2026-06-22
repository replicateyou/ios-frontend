import Foundation
import Combine

/// Wraps Dynamic SDK wallet operations.
@MainActor
class WalletService: ObservableObject {
    static let shared = WalletService()

    @Published var address: String?
    @Published var balance: String = "0"

    private var cancellables = Set<AnyCancellable>()

    func onWalletsUpdated() {
        // Called by AppState when Dynamic SDK reports wallet changes.
        // Fetch balance once we have an address.
        guard let addr = address else { return }
        _ = addr // will be used when we call getBalance below
        Task { await refreshBalance() }
    }

    func refreshBalance() async {
        guard let addr = address else {
            balance = "0.00 OG"
            return
        }
        do {
            let fetched = try await WalletService.fetchEthBalance(address: addr, rpcUrl: Constants.rpcUrl)
            balance = fetched
        } catch {
            print("Balance fetch error: \(error)")
            balance = "— OG"
        }
    }

    static func fetchEthBalance(address: String, rpcUrl: String) async throws -> String {
        guard let url = URL(string: rpcUrl) else { throw URLError(.badURL) }
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getBalance",
            "params": [address, "latest"],
            "id": 1
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hexResult = json["result"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        // Convert hex wei -> OG (18 decimals). Parse via Double to avoid integer overflow.
        let hex = hexResult.hasPrefix("0x") ? String(hexResult.dropFirst(2)) : hexResult
        guard !hex.isEmpty else { return "0.00 OG" }
        // Build a Double from the hex string character by character (safe for typical balances).
        var wei: Double = 0
        for ch in hex {
            guard let digit = ch.hexDigitValue else { return "0.00 OG" }
            wei = wei * 16 + Double(digit)
        }
        let og = wei / 1e18
        return String(format: "%.1f OG", og)
    }
}
