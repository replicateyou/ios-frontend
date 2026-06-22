import SwiftUI
import AVKit

struct LivePlayerView: View {
    let stream: Stream
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView("Connecting…")
                    .tint(.white)
                    .foregroundStyle(.white)
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("LIVE")
                            .font(.caption).fontWeight(.bold).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.black.opacity(0.5)).clipShape(Capsule())
                }
                .padding()
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stream.title).font(.headline).foregroundStyle(.white)
                        Text(stream.shortAddress).font(.caption).foregroundStyle(.white.opacity(0.7)).fontDesign(.monospaced)
                    }
                    Spacer()
                }
                .padding()
                .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
            }
        }
        .onAppear { loadStream() }
        .onDisappear { player?.pause() }
    }

    private func loadStream() {
        guard let url = stream.hlsUrl else { return }
        let p = AVPlayer(url: url)
        p.play()
        player = p
    }
}

#Preview {
    LivePlayerView(stream: Stream.mocks[0])
}
