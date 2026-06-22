import Foundation

// MARK: - StreamBetWebSocket

@MainActor
class StreamBetWebSocket: ObservableObject {
    static let shared = StreamBetWebSocket()

    @Published var oddsUpdates: [String: WSOddsUpdate] = [:]
    @Published var recentBets: [WSBetPlaced] = []
    @Published var resolvedMarkets: [String: WSMarketResolved] = [:]
    @Published var isConnected = false

    private var task: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectDelay: TimeInterval = 1
    private var subscribedMarkets: Set<String> = []

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Connection

    func connect(token: String?) {
        disconnect()
        // TODO: Replace with your own websocket URL when available
        let urlString = ""
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return }

        let session = URLSession(configuration: .default)
        task = session.webSocketTask(with: url)
        task?.resume()
        isConnected = true
        reconnectDelay = 1
        startReceiving()
        startPingTimer()

        // Resubscribe to any markets after reconnect
        if !subscribedMarkets.isEmpty {
            subscribe(marketIds: Array(subscribedMarkets))
        }
    }

    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        isConnected = false
    }

    // MARK: - Subscriptions

    func subscribe(marketIds: [String]) {
        subscribedMarkets.formUnion(marketIds)
        send(["type": "subscribe", "market_ids": marketIds])
    }

    func unsubscribe(marketIds: [String]) {
        subscribedMarkets.subtract(marketIds)
        send(["type": "unsubscribe", "market_ids": marketIds])
    }

    // MARK: - Internal

    private func send(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(str)) { _ in }
    }

    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.task?.send(.string("{\"type\":\"ping\"}")) { _ in }
            }
        }
    }

    private func startReceiving() {
        task?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.startReceiving()
                case .failure:
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message,
              let data = text.data(using: .utf8),
              let event = try? decoder.decode(WSEvent.self, from: data) else { return }

        switch event.type {
        case "odds_update":
            if let update = try? decoder.decode(WSOddsUpdate.self, from: data) {
                oddsUpdates[update.marketId] = update
            }
        case "bet_placed":
            if let bet = try? decoder.decode(WSBetPlaced.self, from: data) {
                recentBets.insert(bet, at: 0)
                if recentBets.count > 50 { recentBets.removeLast() }
            }
        case "agent_bet":
            if let bet = try? decoder.decode(WSBetPlaced.self, from: data) {
                recentBets.insert(bet, at: 0)
                if recentBets.count > 50 { recentBets.removeLast() }
            }
        case "market_resolved":
            if let resolved = try? decoder.decode(WSMarketResolved.self, from: data) {
                resolvedMarkets[resolved.marketId] = resolved
            }
        default:
            break
        }
    }

    private func scheduleReconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
            guard let self else { return }
            self.reconnectDelay = min(self.reconnectDelay * 2, 30)
            // Only reconnect if we have markets to watch
            if !self.subscribedMarkets.isEmpty {
                self.connect(token: StreamBetClient.shared.authToken)
            }
        }
    }
}
