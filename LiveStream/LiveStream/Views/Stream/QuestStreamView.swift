import SwiftUI
import AVFoundation
import Combine

// MARK: - Camera Manager

@MainActor
final class CameraManager: NSObject, ObservableObject {
    @Published var isAuthorized = false

    let session = AVCaptureSession()
    private var hasConfigured = false
    private var movieOutput: AVCaptureMovieFileOutput?
    var onChunkReady: ((URL) -> Void)?

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

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        let output = AVCaptureMovieFileOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            movieOutput = output
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func startChunk() {
        guard let movieOutput, !movieOutput.isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chunk-\(UUID().uuidString).mp4")
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }

    func stopChunk() {
        guard let movieOutput, movieOutput.isRecording else { return }
        movieOutput.stopRecording()
    }
}

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        guard error == nil else { return }
        Task { @MainActor [weak self] in
            self?.onChunkReady?(outputFileURL)
        }
    }
}

// MARK: - Stream View Model

@MainActor
final class StreamViewModel: ObservableObject {
    @Published var elapsedSeconds = 0
    @Published var chunkSecondsElapsed = 0
    @Published var accuracy: Double = 0
    @Published var totalEarned: Double = 0
    @Published var statusMessage = "Starting..."
    @Published var uploadsInFlight = 0
    @Published var isCameraAuthorized = false
    @Published var blinkOn = true

    let camera = CameraManager()

    private let quest: Quest
    private let workerAddress: String
    private var isActive = false
    private var isTransitioningChunk = false
    private var cancellables = Set<AnyCancellable>()

    init(quest: Quest, workerAddress: String) {
        self.quest = quest
        self.workerAddress = workerAddress

        camera.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var formattedTime: String {
        String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    var formattedEarnings: String {
        String(format: "%.3f", totalEarned)
    }

    var secondsUntilNextChunk: Int {
        max(0, 30 - chunkSecondsElapsed)
    }

    var accuracyColor: Color {
        if accuracy >= 80 { return .green }
        if accuracy >= 50 { return .yellow }
        return accuracy == 0 ? .gray : .red
    }

    func start() async {
        await camera.setup()
        isCameraAuthorized = camera.isAuthorized
        isActive = true
        statusMessage = "Analyzing stream..."
        beginChunk()
    }

    func stop() {
        isActive = false
        camera.onChunkReady = nil
        camera.stopChunk()
        camera.stop()
    }

    func tick() {
        elapsedSeconds += 1
        chunkSecondsElapsed += 1
        if chunkSecondsElapsed >= 30, !isTransitioningChunk {
            isTransitioningChunk = true
            camera.stopChunk()
        }
    }

    // MARK: - Chunk lifecycle

    private func beginChunk() {
        isTransitioningChunk = false
        chunkSecondsElapsed = 0

        camera.onChunkReady = { [weak self] url in
            guard let self else { return }
            // Start next chunk immediately so recording is continuous
            if self.isActive { self.beginChunk() }
            // Upload completed chunk concurrently
            Task { await self.uploadChunk(at: url) }
        }

        camera.startChunk()
    }

    private func uploadChunk(at url: URL) async {
        defer { try? FileManager.default.removeItem(at: url) }
        uploadsInFlight += 1
        defer { uploadsInFlight -= 1 }

        do {
            let data = try Data(contentsOf: url)
            let result = try await RelayService.shared.uploadClip(
                data,
                category: quest.name,
                workerAddress: workerAddress
            )
            accuracy = Double(result.score)
            totalEarned += result.payoutA0GI
            statusMessage = result.isAccepted
                ? "Verified — score \(result.score)"
                : "Score \(result.score) — keep going"
        } catch {
            statusMessage = "Upload error — continuing"
        }
    }
}

// MARK: - Camera Preview

class PreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
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
    let workerAddress: String

    @StateObject private var model: StreamViewModel
    @Environment(\.dismiss) private var dismiss

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let blinkTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    init(quest: Quest, workerAddress: String = "") {
        self.quest = quest
        self.workerAddress = workerAddress
        _model = StateObject(wrappedValue: StreamViewModel(quest: quest, workerAddress: workerAddress))
    }

    var body: some View {
        ZStack {
            if model.isCameraAuthorized {
                CameraPreviewView(session: model.camera.session)
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

            VStack {
                LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 300)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(model.blinkOn ? .red : .red.opacity(0.3))
                            .frame(width: 10, height: 10)
                        Text("LIVE")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.8), in: Capsule())

                    Spacer()

                    Text(model.formattedTime)
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5), in: Capsule())

                    Spacer()

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
                    // Status
                    HStack(spacing: 8) {
                        if model.uploadsInFlight > 0 {
                            ProgressView()
                                .tint(.purple)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "brain.head.profile")
                                .foregroundStyle(.purple)
                        }
                        Text(model.statusMessage)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())

                    // Stats row
                    HStack(spacing: 24) {
                        // AI score
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(.white.opacity(0.2), lineWidth: 6)
                                    .frame(width: 64, height: 64)
                                Circle()
                                    .trim(from: 0, to: model.accuracy / 100)
                                    .stroke(model.accuracyColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .frame(width: 64, height: 64)
                                    .rotationEffect(.degrees(-90))
                                Text("\(Int(model.accuracy))%")
                                    .font(.system(.callout, design: .rounded).bold())
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                            }
                            Text("AI Score")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 1, height: 60)

                        // Earnings
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(.green.opacity(0.15))
                                    .frame(width: 64, height: 64)
                                Text(model.formattedEarnings)
                                    .font(.system(size: 11, design: .rounded).bold())
                                    .foregroundStyle(.green)
                                    .contentTransition(.numericText())
                            }
                            Text("A0GI")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 1, height: 60)

                        // Next clip countdown
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .stroke(.white.opacity(0.2), lineWidth: 6)
                                    .frame(width: 64, height: 64)
                                Circle()
                                    .trim(from: 0, to: Double(30 - model.secondsUntilNextChunk) / 30)
                                    .stroke(.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                    .frame(width: 64, height: 64)
                                    .rotationEffect(.degrees(-90))
                                Text("\(model.secondsUntilNextChunk)s")
                                    .font(.system(.callout, design: .rounded).bold())
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())
                            }
                            Text("Next clip")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                    // End stream
                    Button {
                        model.stop()
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
        .task { await model.start() }
        .onReceive(ticker) { _ in model.tick() }
        .onReceive(blinkTimer) { _ in model.blinkOn.toggle() }
        .animation(.easeInOut(duration: 0.4), value: model.accuracy)
        .animation(.easeInOut(duration: 0.3), value: model.totalEarned)
    }
}

#Preview {
    QuestStreamView(quest: Quest.samples[1])
}
