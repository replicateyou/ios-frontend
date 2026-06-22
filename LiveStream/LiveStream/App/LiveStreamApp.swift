import SwiftUI
import DynamicSDKSwift

@main
struct ArcadiaApp: App {
    @StateObject private var appState = AppState()

    init() {
        let galileo = GenericNetwork(
            blockExplorerUrls: ["https://chainscan-galileo.0g.ai"],
            chainId: Constants.chainId,
            chainName: "0G Galileo Testnet",
            iconUrls: [],
            lcdUrl: nil,
            name: "0G Galileo Testnet",
            nameService: nil,
            nativeCurrency: NativeCurrency(
                decimals: 18,
                name: "0G",
                symbol: "0G"
            ),
            networkId: Constants.chainId,
            privateCustomerRpcUrls: nil,
            rpcUrls: [Constants.rpcUrl],
            vanityName: "0G Galileo"
        )

        do {
            _ = try DynamicSDK.initialize(
                props: ClientProps(
                    environmentId: Constants.dynamicEnvironmentId,
                    appLogoUrl: Constants.appLogoUrl,
                    appName: Constants.appName,
                    redirectUrl: Constants.redirectUrl,
                    appOrigin: Constants.appOrigin,
                    evmNetworks: [galileo]
                )
            )
            print("✅ DynamicSDK initialized successfully")
        } catch {
            print("❌ Failed to initialize DynamicSDK: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
