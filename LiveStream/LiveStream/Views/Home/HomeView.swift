import SwiftUI

struct HomeView: View {
    var body: some View {
        TabView {
            NavigationStack {
                Text("Home")
                    .navigationTitle("Home")
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
