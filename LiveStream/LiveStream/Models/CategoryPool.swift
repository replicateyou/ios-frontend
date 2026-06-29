import Foundation

struct CategoryPool: Codable, Identifiable {
    let category: String
    let fundReserve: String
    let virtualSupply: String
    let totalShares: String
    let currentPrice: String

    var id: String { category }
}

extension CategoryPool {
    var currentPriceA0GI: Double { weiToDouble(currentPrice) }
    var fundReserveA0GI: Double { weiToDouble(fundReserve) }

    private func weiToDouble(_ wei: String) -> Double {
        guard let value = Double(wei) else { return 0 }
        return value / 1e18
    }
}
