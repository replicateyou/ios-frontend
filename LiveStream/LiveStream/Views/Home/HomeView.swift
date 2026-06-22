import SwiftUI

struct HomeView: View {
    var body: some View {
        TabView {
            StreamFeedView()
                .tabItem {
                    Label("Streams", systemImage: "play.rectangle.fill")
                }

            BroadcastView()
                .tabItem {
                    Label("Go Live", systemImage: "video.badge.plus")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
        .tint(.red)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
