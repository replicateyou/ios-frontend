import Foundation
import Combine
import DynamicSDKSwift

private enum SessionKeys {
    static let isAuthenticated = "session_isAuthenticated"
    static let authToken = "session_authToken"
    static let walletAddress = "session_walletAddress"
    static let userName = "session_userName"
}

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isReady = false
    @Published var walletAddress: String?
    @Published var userName: String?
    @Published var authToken: String?

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Restore persisted session so user doesn't need to re-login.
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: SessionKeys.isAuthenticated),
           let token = defaults.string(forKey: SessionKeys.authToken) {
            isAuthenticated = true
            authToken = token
            walletAddress = defaults.string(forKey: SessionKeys.walletAddress)
            userName = defaults.string(forKey: SessionKeys.userName)
            StreamBetClient.shared.authToken = token
            WalletService.shared.address = walletAddress
            if walletAddress != nil { WalletService.shared.onWalletsUpdated() }
            StreamBetWebSocket.shared.connect(token: token)
        }

        guard let sdk = try? DynamicSDK.shared else {
            print("⚠️ DynamicSDK not initialized yet")
            isReady = true
            return
        }

        sdk.auth.authenticatedUserChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self else { return }
                self.isAuthenticated = user != nil
                self.userName = user?.email
                self.isReady = true
                self.persistSession()
            }
            .store(in: &cancellables)

        sdk.auth.tokenChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] token in
                self?.authToken = token
                StreamBetClient.shared.authToken = token
                self?.persistSession()
                if let token {
                    StreamBetWebSocket.shared.connect(token: token)
                }
            }
            .store(in: &cancellables)

        sdk.wallets.userWalletsChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] wallets in
                self?.walletAddress = wallets.first(where: { $0.chain == "EVM" })?.address
                WalletService.shared.address = self?.walletAddress
                WalletService.shared.onWalletsUpdated()
                self?.persistSession()
            }
            .store(in: &cancellables)
    }

    private func persistSession() {
        let defaults = UserDefaults.standard
        defaults.set(isAuthenticated, forKey: SessionKeys.isAuthenticated)
        defaults.set(authToken, forKey: SessionKeys.authToken)
        defaults.set(walletAddress, forKey: SessionKeys.walletAddress)
        defaults.set(userName, forKey: SessionKeys.userName)
    }

    func logout() async {
        do {
            try await DynamicSDK.shared.auth.logout()
        } catch {
            print("Logout failed: \(error)")
        }
        // Clear persisted session.
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: SessionKeys.isAuthenticated)
        defaults.removeObject(forKey: SessionKeys.authToken)
        defaults.removeObject(forKey: SessionKeys.walletAddress)
        defaults.removeObject(forKey: SessionKeys.userName)
    }

    var shortAddress: String? {
        guard let addr = walletAddress, addr.count > 10 else { return walletAddress }
        return addr.prefix(6) + "..." + addr.suffix(4)
    }
}
