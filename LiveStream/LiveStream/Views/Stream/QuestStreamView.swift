import SwiftUI
import AVFoundation

// MARK: - Camera Manager

@MainActor
final class CameraManager: ObservableObject {
    @Published var isAuthorized = false

    let session = AVCaptureSession()
    private var hasConfigured = false

    func setup() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            isAuthorized = granted
        } else {
            isAuthorized = status == .authorized
        }

        guard isAuthorized, !hasConfigured else { return }
        hasConfigured = true

        session.beginConfiguration()
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }
}

// MARK: - Camera Preview

class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

// MARK: - Stream View

struct QuestStreamView: View {
    let quest: Quest
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraManager()

    @State private var elapsedSeconds = 0
    @State private var accuracy: Double = 0
    @State private var earnings: Double = 0
    @State private var statusMessage = "Initializing..."
    @State private var blinkOn = true

    private let earningsTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let accuracyTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let blinkTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Camera background
            if camera.isAuthorized {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)
                    Text("Camera access required")
                        .foregroundStyle(.gray)
                }
            }

            // Gradient overlays for readability
            VStack {
                LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 300)
            }
            .ignoresSafeArea()

            // HUD
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    // LIVE badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(blinkOn ? .red : .red.opacity(0.3))
                            .frame(width: 10, height: 10)
                        Text("LIVE")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.8), in: Capsule())

                    Spacer()

                    // Timer
                    Text(formattedTime)
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5), in: Capsule())

                    Spacer()

                    // Quest label
                    Text(quest.name)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.purple.opacity(0.8), in: Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Bottom overlay
                VStack(spacing: 16) {
                    // Status message
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .foregroundStyle(.purple)
                        Text(statusMessage)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())

                    // Stats row
                    HStack(spacing: 24) {
                        // Accuracy gauge
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(.white.opacity(0.2), lineWidth: 6)
                                    .frame(width: 64, height: 64)
                                Circle()
                                    .trim(from: 0, to: accuracy / 100)
                                    .stroke(accuracyColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .frame(width: 64, height: 64)
                                    .rotationEffect(.degrees(-90))
                                Text("\(Int(accuracy))%")
                                    .font(.system(.callout, design: .rounded).bold())
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                            }
                            Text("Task Match")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        // Divider
                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 1, height: 60)

                        // Earnings
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(.green.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                Text(formattedEarnings)
                                    .font(.system(.callout, design: .rounded).bold())
                                    .foregroundStyle(.green)
                                    .contentTransition(.numericText())
                            }
                            Text("Earned")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        // Divider
                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 1, height: 60)

                        // Rate
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(.purple.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                Text("$\(quest.hourlyRate)")
                                    .font(.system(.callout, design: .rounded).bold())
                                    .foregroundStyle(.purple)
                            }
                            Text("$/hr")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                    // End stream button
                    Button {
                        camera.stop()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("End Stream")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
        }
        .statusBarHidden()
        .task { await camera.setup() }
        .onReceive(earningsTimer) { _ in tickEarnings() }
        .onReceive(accuracyTimer) { _ in tickAccuracy() }
        .onReceive(blinkTimer) { _ in blinkOn.toggle() }
        .animation(.easeInOut(duration: 0.4), value: accuracy)
        .animation(.easeInOut(duration: 0.3), value: earnings)
    }

    // MARK: - Computed

    private var formattedTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var formattedEarnings: String {
        String(format: "$%.2f", earnings)
    }

    private var accuracyColor: Color {
        if accuracy >= 80 { return .green }
        if accuracy >= 50 { return .yellow }
        return .red
    }

    // MARK: - Simulation

    private func tickEarnings() {
        elapsedSeconds += 1
        let ratePerSecond = Double(quest.hourlyRate) / 3600.0
        earnings += ratePerSecond * (accuracy / 100.0)
    }

    private func tickAccuracy() {
        let elapsed = Double(elapsedSeconds)

        if elapsed < 3 {
            accuracy = min(accuracy + Double.random(in: 15...25), 40)
            statusMessage = "Analyzing stream..."
        } else if elapsed < 7 {
            let target = Double.random(in: 75...90)
            accuracy = min(accuracy + (target - accuracy) * 0.5, 95)
            statusMessage = "Task detected"
        } else {
            let fluctuation = Double.random(in: -5...5)
            accuracy = min(max(accuracy + fluctuation, 70), 98)

            let questSpecific = "\(quest.name) in progress"
            let options = [questSpecific, "On task — verified", "On task — verified", questSpecific]
            statusMessage = options.randomElement() ?? "On task — verified"
        }
    }
}

#Preview {
    QuestStreamView(quest: Quest.samples[1])
}
