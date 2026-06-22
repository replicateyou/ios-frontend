import Foundation

// MARK: - Enums

enum SBMarketStatus: String, Codable {
    case active, resolved, cancelled
}

enum SBBetSide: String, Codable {
    case yes, no
}

// MARK: - Market list item (GET /v1/markets)

struct SBMarket: Identifiable, Codable {
    var id: String { marketId }
    let marketId: String
    let streamId: String
    let title: String
    let condition: String
    let streamUrl: String
    let status: SBMarketStatus
    let createdBy: String
    let isAgentStream: Bool
    let yesOdds: Double
    let noOdds: Double
    let yesPoolWei: String
    let noPoolWei: String
    let totalVolumeWei: String
    let startsAt: Int
    let endsAt: Int
    let secondsRemaining: Int?
    let nextCursor: String?
    let total: Int?

    var yesPoolEth: Double { weiToEth(yesPoolWei) }
    var noPoolEth: Double { weiToEth(noPoolWei) }
    var totalVolumeEth: Double { weiToEth(totalVolumeWei) }
}

struct PaginatedMarkets: Codable {
    let markets: [SBMarket]
    let nextCursor: String?
    let total: Int
}

// MARK: - Market detail (GET /v1/markets/:id)

struct SBMarketDetail: Codable {
    let marketId: String
    let streamId: String
    let streamUrl: String
    let title: String
    let condition: String
    let status: SBMarketStatus
    let outcome: String?
    let resolutionReason: String?
    let trioExplanation: String?
    let resolvedAt: Int?
    let resolveTxHash: String?
    let yesOdds: Double
    let noOdds: Double
    let yesPoolWei: String
    let noPoolWei: String
    let totalVolumeWei: String
    let startsAt: Int
    let endsAt: Int
    let agentPositions: [SBAgentPosition]
    let recentBets: [SBRecentBet]

    var yesPoolEth: Double { weiToEth(yesPoolWei) }
    var noPoolEth: Double { weiToEth(noPoolWei) }
    var totalVolumeEth: Double { weiToEth(totalVolumeWei) }
}

struct SBAgentPosition: Codable {
    let agentId: String
    let agentName: String
    let side: SBBetSide
    let amountWei: String
    let pctPool: Double

    var amountEth: Double { weiToEth(amountWei) }
}

struct SBRecentBet: Identifiable, Codable {
    var id: String { betId }
    let betId: String
    let userId: String
    let side: SBBetSide
    let amountWei: String
    let placedAt: Int

    var amountEth: Double { weiToEth(amountWei) }
}

// MARK: - Bet response (POST /v1/markets/:id/bet)

struct SBBetResponse: Codable {
    let betId: String
    let marketId: String
    let userId: String
    let side: SBBetSide
    let amountWei: String
    let txHash: String
    let placedAt: Int
    let updatedOdds: SBUpdatedOdds
    let mirroredBets: [SBMirroredBet]
}

struct SBUpdatedOdds: Codable {
    let yesOdds: Double
    let noOdds: Double
    let yesPoolWei: String
    let noPoolWei: String
    let totalVolumeWei: String
}

struct SBMirroredBet: Codable {
    let betId: String
    let userId: String
    let side: SBBetSide
    let amountWei: String
}

// MARK: - Stream market (POST /v1/stream)

struct SBStreamMarket: Codable {
    let streamId: String
    let marketId: String
    let trioJobId: String
    let streamUrl: String
    let condition: String
    let title: String
    let status: SBMarketStatus
    let createdBy: String
    let isAgentStream: Bool
    let market: SBMarketPool
    let startsAt: Int
    let endsAt: Int
    let resolved: Bool
    let txHash: String
}

struct SBMarketPool: Codable {
    let yesPoolWei: String
    let noPoolWei: String
    let yesOdds: Double
    let noOdds: Double
    let totalVolumeWei: String
    let bettorsCount: Int
}

// MARK: - WebSocket event models

struct WSEvent: Codable {
    let type: String
}

struct WSOddsUpdate: Codable {
    let type: String
    let marketId: String
    let yesOdds: Double
    let noOdds: Double
    let yesPoolWei: String
    let noPoolWei: String
    let totalVolumeWei: String
    let secondsRemaining: Int
    let ts: Int
}

struct WSBetPlaced: Identifiable, Codable {
    var id: String { betId }
    let type: String
    let marketId: String
    let betId: String
    let userId: String
    let isAgent: Bool
    let side: SBBetSide
    let amountWei: String
    let txHash: String
    let ts: Int

    var amountEth: Double { weiToEth(amountWei) }
}

struct WSMarketResolved: Codable {
    let type: String
    let marketId: String
    let outcome: String
    let resolutionReason: String
    let trioExplanation: String?
    let resolvedAt: Int
    let txHash: String
    let winningPoolWei: String?
    let totalPotWei: String
}

struct WSAgentBet: Codable {
    let type: String
    let marketId: String
    let betId: String
    let agentId: String
    let agentName: String
    let side: SBBetSide
    let amountWei: String
    let ts: Int
}

// MARK: - Helpers

private func weiToEth(_ wei: String) -> Double {
    guard let value = Double(wei) else { return 0 }
    return value / 1e18
}
