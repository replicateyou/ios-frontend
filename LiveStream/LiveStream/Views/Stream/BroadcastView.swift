import SwiftUI
import AVFoundation

struct BroadcastView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var broadcaster = HLSBroadcastService.shared
    @StateObject private var machinefi = MachineFiService.shared
    @State private var streamTitle = ""
    @State private var resolveCondition = "Will the watch be stolen?"
    @State private var isStartingStream = false
    @State private var currentStreamId: String?
    @State private var showEndConfirm = false
    @State private var showPermissionAlert = false
    @State private var goLiveError: String?
    @State private var showMarketResolved = false
    @State private var verifyCondition = "Will the watch be stolen?"
    @FocusState private var isConditionFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if broadcaster.isLive {
                    liveView
                } else {
                    previewView
                }
            }
            .navigationTitle(broadcaster.isLive ? "" : "Go Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Market Resolved", isPresented: $showMarketResolved) {
                Button("OK") {}
            } message: {
                Text("The stream has ended and the market has been resolved.")
            }
        }
    }

    // MARK: - Pre-live setup

    private var previewView: some View {
        VStack(spacing: 0) {
            CameraPreviewView(session: broadcaster.session)
                .frame(maxWidth: .infinity)
                .aspectRatio(9/16, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
                .onTapGesture {
                    isConditionFieldFocused = false
                }

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resolve condition")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    TextField("e.g. Will the bike fall into the ditch?", text: $resolveCondition, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .padding(.horizontal)
                        .focused($isConditionFieldFocused)
                        .submitLabel(.done)
                        .onKeyPress(.return) {
                            isConditionFieldFocused = false
                            return .handled
                        }
                }

                if let err = goLiveError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    goLiveError = nil
                    Task { await goLive() }
                } label: {
                    HStack {
                        if isStartingStream {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "dot.radiowaves.left.and.right")
                            Text("Go Live")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }
                .disabled(resolveCondition.trimmingCharacters(in: .whitespaces).count < 5 || isStartingStream)
            }
            .padding(.top, 24)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isConditionFieldFocused = false
        }
        .onAppear {
            try? broadcaster.setupSession()
            broadcaster.startSession()
        }
        .onDisappear { if !broadcaster.isLive { broadcaster.stopSession() } }
        .alert("Camera Access Needed", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow camera and microphone access in Settings.")
        }
    }

    // MARK: - Live broadcast

    private var liveView: some View {
        ZStack {
            CameraPreviewView(session: broadcaster.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    liveBadge
                    Spacer()
                    Text(timeString(broadcaster.elapsedSeconds))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                }
                .padding()

                Spacer()

                VStack(spacing: 8) {
                    // Stream info + end button
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(streamTitle)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(appState.shortAddress ?? "")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .fontDesign(.monospaced)
                        }
                        Spacer()
                        Button {
                            showEndConfirm = true
                        } label: {
                            Text("End")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(.red)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding()
                .background(.black.opacity(0.6))
            }
        }
        .confirmationDialog("End live stream?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End Stream", role: .destructive) {
                Task { await endStream() }
            }
            Button("Keep Streaming", role: .cancel) {}
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
            Text("LIVE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.5))
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func goLive() async {
        guard await checkPermissions() else {
            showPermissionAlert = true
            return
        }

        isStartingStream = true
        defer { isStartingStream = false }

        do {
            let streamId = try await APIClient.shared.startStream(
                title: streamTitle,
                creatorAddress: appState.walletAddress ?? "unknown"
            )
            currentStreamId = streamId
            broadcaster.startBroadcast(streamId: streamId)

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(10))
                await endStream()
                try? await Task.sleep(for: .milliseconds(400))
                showMarketResolved = true
            }

            let streamUrl = APIClient.shared.publicHlsUrl(for: streamId).absoluteString
            let condition = resolveCondition.trimmingCharacters(in: .whitespaces)
            _ = try await APIClient.shared.createMarket(
                streamUrl: streamUrl,
                condition: condition,
                title: streamTitle.isEmpty ? nil : streamTitle,
                initialLiquidityWei: "500000000000000000"
            )
        } catch {
            goLiveError = error.localizedDescription
        }
    }

    private func endStream() async {
        await broadcaster.stopBroadcast()
        if let streamId = currentStreamId {
            _ = try? await APIClient.shared.endStream(streamId: streamId)
        }
        currentStreamId = nil
        streamTitle = ""
        resolveCondition = "Will the watch be stolen?"
    }

    private func checkPermissions() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            return await AVCaptureDevice.requestAccess(for: .video)
        }
        return status == .authorized
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Camera preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        var session: AVCaptureSession? {
            didSet { previewLayer.session = session }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.videoGravity = .resizeAspectFill
        }
    }
}

#Preview {
    BroadcastView()
        .environmentObject(AppState())
}
