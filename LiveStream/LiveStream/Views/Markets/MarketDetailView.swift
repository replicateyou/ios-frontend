import SwiftUI

struct MarketDetailView: View {
    let marketId: String

    @StateObject private var ws = StreamBetWebSocket.shared
    @State private var detail: SBMarketDetail?
    @State private var isLoading = true
    @State private var betSide: SBBetSide = .yes
    @State private var betAmountEth: String = "0.01"
    @State private var isPlacingBet = false
    @State private var betError: String?
    @State private var betSuccess = false

    private var currentOdds: (yes: Double, no: Double) {
        if let update = ws.oddsUpdates[marketId] {
            return (update.yesOdds, update.noOdds)
        }
        return (detail?.yesOdds ?? 0.5, detail?.noOdds ?? 0.5)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading market…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let detail {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            headerSection(detail)
                            oddsSection
                            betSection
                            if !detail.agentPositions.isEmpty {
                                agentPositionsSection(detail)
                            }
                            recentBetsSection(detail)
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView("Market not found", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle("Market")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Bet placed!", isPresented: $betSuccess) {
                Button("OK", role: .cancel) {}
            }
            .alert("Bet failed", isPresented: Binding(get: { betError != nil }, set: { if !$0 { betError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(betError ?? "")
            }
        }
        .task {
            await loadDetail()
            StreamBetWebSocket.shared.subscribe(marketIds: [marketId])
        }
        .onDisappear {
            StreamBetWebSocket.shared.unsubscribe(marketIds: [marketId])
        }
    }

    // MARK: - Sections

    private func headerSection(_ detail: SBMarketDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detail.title)
                .font(.title3)
                .fontWeight(.bold)

            Label(detail.condition, systemImage: "questionmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Link(destination: URL(string: detail.streamUrl) ?? URL(string: "https://arcadia.app")!) {
                Label("View Stream", systemImage: "play.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            if let resolved = ws.resolvedMarkets[marketId] {
                resolvedBanner(resolved)
            } else if detail.status == .resolved, let outcome = detail.outcome {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Resolved: \(outcome.uppercased())")
                        .fontWeight(.semibold)
                    if let explanation = detail.trioExplanation {
                        Text("· \(explanation)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .padding(10)
                .background(outcome == "yes" ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var oddsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Odds")
                .font(.headline)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(.green)
                        .frame(width: geo.size.width * currentOdds.yes, height: 28)
                        .clipShape(.rect(topLeadingRadius: 8, bottomLeadingRadius: 8))
                    Rectangle()
                        .fill(.red)
                        .frame(width: geo.size.width * currentOdds.no, height: 28)
                        .clipShape(.rect(bottomTrailingRadius: 8, topTrailingRadius: 8))
                }
                .animation(.easeInOut(duration: 0.3), value: currentOdds.yes)
            }
            .frame(height: 28)

            HStack {
                Label(String(format: "YES %.0f%%", currentOdds.yes * 100), systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
                Label(String(format: "NO %.0f%%", currentOdds.no * 100), systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let detail {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.4f ETH", detail.yesPoolEth))
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("YES pool")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.4f ETH", detail.noPoolEth))
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text("NO pool")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var betSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Place Bet")
                .font(.headline)

            Picker("Side", selection: $betSide) {
                Text("YES").tag(SBBetSide.yes)
                Text("NO").tag(SBBetSide.no)
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Amount (ETH)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("0.01", text: $betAmountEth)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
            }

            Button {
                Task { await placeBet() }
            } label: {
                HStack {
                    if isPlacingBet {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: betSide == .yes ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        Text("Bet \(betSide.rawValue.uppercased())")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(betSide == .yes ? Color.green : Color.red)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isPlacingBet || betAmountEth.isEmpty)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func agentPositionsSection(_ detail: SBMarketDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agent Positions")
                .font(.headline)

            ForEach(detail.agentPositions, id: \.agentId) { pos in
                HStack {
                    Image(systemName: "cpu")
                        .foregroundStyle(.purple)
                    Text(pos.agentName)
                        .font(.subheadline)
                    Spacer()
                    Text(pos.side.rawValue.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(pos.side == .yes ? .green : .red)
                    Text(String(format: "%.4f ETH", pos.amountEth))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func recentBetsSection(_ detail: SBMarketDetail) -> some View {
        let wsBets = ws.recentBets.filter { $0.marketId == marketId }
        let staticBets = detail.recentBets

        return VStack(alignment: .leading, spacing: 8) {
            Text("Recent Bets")
                .font(.headline)

            if wsBets.isEmpty && staticBets.isEmpty {
                Text("No bets yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(wsBets.prefix(10)) { bet in
                    BetRow(
                        side: bet.side,
                        amountEth: bet.amountEth,
                        isAgent: bet.isAgent,
                        label: "Live"
                    )
                }
                ForEach(staticBets.prefix(10 - min(wsBets.count, 10))) { bet in
                    BetRow(
                        side: bet.side,
                        amountEth: bet.amountEth,
                        isAgent: false,
                        label: nil
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func resolvedBanner(_ resolved: WSMarketResolved) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                Text("Resolved: \(resolved.outcome.uppercased())")
                    .fontWeight(.semibold)
            }
            if let explanation = resolved.trioExplanation {
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(resolved.outcome == "yes" ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Actions

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }
        detail = try? await StreamBetClient.shared.getMarketDetail(id: marketId)
    }

    private func placeBet() async {
        guard let ethValue = Double(betAmountEth) else { return }
        let weiStr = String(UInt64(ethValue * 1e18))
        isPlacingBet = true
        defer { isPlacingBet = false }
        do {
            _ = try await StreamBetClient.shared.placeBet(marketId: marketId, side: betSide, amountWei: weiStr)
            betSuccess = true
            await loadDetail()
        } catch {
            betError = error.localizedDescription
        }
    }
}

// MARK: - Bet Row

struct BetRow: View {
    let side: SBBetSide
    let amountEth: Double
    let isAgent: Bool
    let label: String?

    var body: some View {
        HStack {
            Image(systemName: isAgent ? "cpu" : "person.fill")
                .font(.caption)
                .foregroundStyle(isAgent ? .purple : .secondary)
            Text(side.rawValue.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(side == .yes ? .green : .red)
            Spacer()
            if let label {
                Text(label)
                    .font(.system(size: 9))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.2))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
            Text(String(format: "%.4f ETH", amountEth))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
