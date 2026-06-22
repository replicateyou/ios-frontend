import SwiftUI

struct QuestDetailView: View {
    let quest: Quest
    @State private var isStreaming = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero header
                VStack(spacing: 12) {
                    Image(systemName: quest.icon)
                        .font(.system(size: 56))
                        .foregroundStyle(.purple)
                        .padding(24)
                        .background(.purple.opacity(0.1), in: Circle())

                    Text(quest.name)
                        .font(.title2.bold())

                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundStyle(.green)
                        Text("$\(quest.hourlyRate)/hr")
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                    }

                    // Live badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("\(quest.streamsOnline) streaming now")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.1), in: Capsule())
                }
                .padding(.top, 24)
                .padding(.bottom, 28)

                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(title: "Submissions", value: formatNumber(quest.totalSubmissions), icon: "checkmark.circle.fill", color: .blue)
                    StatCard(title: "Live Streams", value: "\(quest.streamsOnline)", icon: "video.fill", color: .red)
                    StatCard(title: "Avg Duration", value: "\(quest.avgDuration) min", icon: "clock.fill", color: .orange)
                    StatCard(title: "Total Earned", value: "$\(formatNumber(quest.totalEarned))", icon: "banknote.fill", color: .green)
                }
                .padding(.horizontal, 16)

                // How it works
                VStack(alignment: .leading, spacing: 16) {
                    Text("How it works")
                        .font(.headline)

                    StepRow(number: 1, text: "Start a live stream of yourself doing the chore")
                    StepRow(number: 2, text: "AI verifies you're completing the task in real-time")
                    StepRow(number: 3, text: "Earn $\(quest.hourlyRate)/hr for every verified minute streamed")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
                .padding(.top, 20)

                Spacer(minLength: 100)
            }
        }
        .navigationTitle(quest.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                isStreaming = true
            } label: {
                HStack {
                    Image(systemName: "video.fill")
                    Text("Start Streaming")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.purple, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .fullScreenCover(isPresented: $isStreaming) {
            QuestStreamView(quest: quest)
        }
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            let k = Double(n) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(n)"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.purple, in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        QuestDetailView(quest: Quest.samples[5])
    }
}
