import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.isReady {
                Color.black.ignoresSafeArea()
            } else if appState.isAuthenticated {
                HomeView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
    }
}
