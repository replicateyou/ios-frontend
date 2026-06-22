import SwiftUI
import AVKit

// MARK: - LoopingVideoPlayer

struct LoopingVideoPlayer: UIViewRepresentable {
    let videoName: String
    let videoExtension: String

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
            return view
        }
        let player = AVPlayer(url: url)
        player.isMuted = true
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(playerLayer)
        player.play()
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - BetView

struct LiveDot: View {
    @State private var blink = false

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 15, height: 15)
            .opacity(blink ? 1 : 0.2)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: blink)
            .onAppear { blink = true }
    }
}

struct BetView: View {
    let videoName: String
    let question: String
    let wager: String
    let yesOdds: Int

    var noOdds: Int { 100 - yesOdds }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                LoopingVideoPlayer(videoName: videoName, videoExtension: "mp4")
                    .ignoresSafeArea()

                // Live indicator
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        LiveDot()
                        Text("LIVE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, geo.safeAreaInsets.top + 50)
                .padding(.trailing, 40)
                .frame(maxHeight: .infinity, alignment: .top)

                // Gradient overlay — covers bottom third
                LinearGradient(
                    colors: [.clear, .black.opacity(1.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geo.size.height / 2)

                // Content sits above the tab bar
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Q: \(question)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Current bet: \(wager)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    HStack(spacing: 12) {
                        BetButton(label: "Yes", odds: yesOdds)
                        BetButton(label: "No", odds: noOdds)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, geo.safeAreaInsets.bottom + 100)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

// MARK: - BetButton

struct BetButton: View {
    let label: String
    let odds: Int

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(odds)%")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }
}

// MARK: - StreamFeedView

struct StreamFeedView: View {
    private let bets: [(video: String, question: String, wager: String, yesOdds: Int)] = [
        ("1", "Will more than 5 people join the party?", "$823", 73),
        ("2", "Will he catch the red ball?", "$2.3k", 41),
        ("3", "Will the man fall off the wall?", "$114", 58),
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(bets, id: \.video) { bet in
                    BetView(videoName: bet.video, question: bet.question, wager: bet.wager, yesOdds: bet.yesOdds)
                        .frame(height: UIScreen.main.bounds.height)
                }
            }
        }
        .scrollTargetBehavior(.paging)
        .ignoresSafeArea()
    }
}

#Preview {
    StreamFeedView()
}
