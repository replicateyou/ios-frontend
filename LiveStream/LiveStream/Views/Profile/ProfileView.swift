import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var balance = "..."

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
        await WalletService.shared.refreshBalance()
        balance = WalletService.shared.balance
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
