import SwiftUI
import AVKit

struct StreamPlayerView: View {
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
                ProgressView("Loading…")
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
                }
                .padding()
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.title).font(.headline).foregroundStyle(.white)
                    Text(stream.shortAddress).font(.caption).foregroundStyle(.white.opacity(0.7)).fontDesign(.monospaced)
                    if let duration = stream.duration {
                        Text("\(duration)s")
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
            }
        }
        .onAppear { loadStream() }
        .onDisappear { player?.pause() }
    }

    private func loadStream() {
        guard let url = stream.archivedUrl else { return }
        let p = AVPlayer(url: url)
        p.play()
        player = p
    }
}

#Preview {
    StreamPlayerView(stream: Stream.mocks[1])
}
