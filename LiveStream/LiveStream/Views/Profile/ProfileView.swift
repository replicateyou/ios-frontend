import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var balance = "..."
    @State private var myStreams: [Stream] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundStyle(.red)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.userName ?? "Anon")
                                .font(.headline)
                            if let addr = appState.walletAddress {
                                Text(addr.prefix(6) + "..." + addr.suffix(4))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fontDesign(.monospaced)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Wallet") {
                    LabeledContent("Balance", value: balance)
                    if let address = appState.walletAddress {
                        LabeledContent("Address") {
                            Text(address)
                                .font(.caption)
                                .fontDesign(.monospaced)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }

                Section("My Streams (\(myStreams.count))") {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if myStreams.isEmpty {
                        Text("No streams yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(myStreams) { stream in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(stream.title).font(.subheadline)
                                    Text(stream.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if stream.status == .live {
                                    Text("LIVE").font(.caption).fontWeight(.bold).foregroundStyle(.red)
                                } else if let duration = stream.duration {
                                    Text("\(duration)s").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await appState.logout()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .task { await loadData() }
            .refreshable { await loadData() }
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        await WalletService.shared.refreshBalance()
        balance = WalletService.shared.balance
        let all = (try? await APIClient.shared.getStreams()) ?? []
        myStreams = all.filter { $0.creatorAddress.lowercased() == appState.walletAddress?.lowercased() }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
