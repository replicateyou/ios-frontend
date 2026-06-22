import SwiftUI

struct HomeView: View {
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(Quest.samples) { quest in
                            NavigationLink(value: quest) {
                                QuestCard(quest: quest)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .navigationTitle("Quests")
                .navigationDestination(for: Quest.self) { quest in
                    QuestDetailView(quest: quest)
                }
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

struct QuestCard: View {
    let quest: Quest

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: quest.icon)
                .font(.system(size: 32))
                .foregroundStyle(.purple)

            Text(quest.name)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("$\(quest.hourlyRate)/hr")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
