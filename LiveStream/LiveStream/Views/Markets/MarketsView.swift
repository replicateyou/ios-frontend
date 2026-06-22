import SwiftUI

struct MarketsView: View {
    @StateObject private var client = StreamBetClient.shared
    @State private var markets: [SBMarket] = []
    @State private var isLoading = false
    @State private var nextCursor: String?
    @State private var selectedMarket: SBMarket?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && markets.isEmpty {
                    ProgressView("Loading markets…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if markets.isEmpty {
                    ContentUnavailableView(
                        "No markets yet",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Go live and create the first prediction market.")
                    )
                } else {
                    List {
                        ForEach(markets) { market in
                            MarketCard(market: market)
                                .onTapGesture { selectedMarket = market }
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .onAppear {
                                    if market.id == markets.last?.id, let cursor = nextCursor {
                                        Task { await loadMore(cursor: cursor) }
                                    }
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Markets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await loadMarkets() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .refreshable { await loadMarkets() }
            .sheet(item: $selectedMarket) { market in
                MarketDetailView(marketId: market.marketId)
            }
        }
        .task { await loadMarkets() }
    }

    private func loadMarkets() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await StreamBetClient.shared.getMarkets(status: "active")
            markets = result.markets
            nextCursor = result.nextCursor
        } catch {
            print("Failed to load markets: \(error)")
        }
    }

    private func loadMore(cursor: String) async {
        do {
            let result = try await StreamBetClient.shared.getMarkets(status: "active", cursor: cursor)
            markets.append(contentsOf: result.markets)
            nextCursor = result.nextCursor
        } catch {
            print("Failed to load more markets: \(error)")
        }
    }
}

// MARK: - Market Card

struct MarketCard: View {
    let market: SBMarket

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(market.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Spacer()

                HStack(spacing: 4) {
                    if market.isAgentStream {
                        Text("AGENT")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.purple.opacity(0.2))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                    statusBadge
                }
            }

            Text(market.condition)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                OddsPill(label: "YES", odds: market.yesOdds, color: .green)
                OddsPill(label: "NO", odds: market.noOdds, color: .red)
                Spacer()
                Text(String(format: "%.4f ETH vol", market.totalVolumeEth))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusBadge: some View {
        Text(market.status.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(market.status == .active ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
            .foregroundStyle(market.status == .active ? .green : .gray)
            .clipShape(Capsule())
    }
}

// MARK: - Odds Pill

struct OddsPill: View {
    let label: String
    let odds: Double
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
            Text(String(format: "%.0f%%", odds * 100))
                .font(.system(size: 11))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

#Preview {
    MarketsView()
}
