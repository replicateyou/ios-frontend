import AVFoundation
import Combine

/// Manages the AVCaptureSession, records video in segments, and uploads each segment to the backend.
@MainActor
class HLSBroadcastService: NSObject, ObservableObject {
    static let shared = HLSBroadcastService()

    @Published var isLive = false
    @Published var elapsedSeconds = 0
    @Published var segmentCount = 0
    @Published var error: String?

    let session = AVCaptureSession()
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var captureVideoInput: AVCaptureDeviceInput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private let captureQueue = DispatchQueue(label: "com.arcadia.capture", qos: .userInitiated)

    private var streamId: String?
    private var segmentTimer: Timer?
    private var elapsedTimer: Timer?
    private var currentSegmentIndex = 0
    private var currentSegmentUrl: URL?
    private var isWritingSegment = false
    private var sessionStarted = false

    private let segmentDuration: TimeInterval = 3.0
    private let maxDuration: TimeInterval = 60.0

    // MARK: - Session setup

    func setupSession() throws {
        guard videoDataOutput == nil else { return } // Already configured
        session.beginConfiguration()
        session.sessionPreset = .high

        // Video input — prefer back camera
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw BroadcastError.noCameraAvailable
        }
        let videoIn = try AVCaptureDeviceInput(device: videoDevice)
        if session.canAddInput(videoIn) { session.addInput(videoIn) }
        captureVideoInput = videoIn

        // Video data output — feeds sample buffers to AVAssetWriter
        let vOut = AVCaptureVideoDataOutput()
        vOut.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        vOut.alwaysDiscardsLateVideoFrames = true
        vOut.setSampleBufferDelegate(self, queue: captureQueue)
        if session.canAddOutput(vOut) { session.addOutput(vOut) }
        videoDataOutput = vOut

        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning else { return }
        let s = session
        Task.detached { s.startRunning() }
    }

    func stopSession() {
        guard session.isRunning else { return }
        let s = session
        Task.detached { s.stopRunning() }
    }

    // MARK: - Broadcast lifecycle

    func startBroadcast(streamId: String) {
        self.streamId = streamId
        self.currentSegmentIndex = 0
        self.elapsedSeconds = 0
        self.segmentCount = 0
        self.isLive = true

        startNewSegment()

        // Segment rotation timer
        segmentTimer = Timer.scheduledTimer(withTimeInterval: segmentDuration, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.rotateSegment()
            }
        }

        // Elapsed time display timer
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.elapsedSeconds += 1
                if self.elapsedSeconds >= Int(self.maxDuration) {
                    await self.stopBroadcast()
                }
            }
        }
    }

    func stopBroadcast() async {
        segmentTimer?.invalidate()
        segmentTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        isLive = false

        await finalizeCurrentSegment()
    }

    // MARK: - Segment management

    private func startNewSegment() {
        let url = segmentUrl(for: currentSegmentIndex)
        currentSegmentUrl = url

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1280,
            AVVideoHeightKey: 720,
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true

        if writer.canAdd(vInput) { writer.add(vInput) }

        assetWriter = writer
        videoInput = vInput

        writer.startWriting()
        // startSession is called on the first sample buffer so the timestamp is accurate
        isWritingSegment = false
        sessionStarted = false
    }

    private func rotateSegment() {
        guard isLive, let writer = assetWriter, writer.status == .writing else { return }
        finalizeAndUploadCurrentSegment()
        currentSegmentIndex += 1
        startNewSegment()
    }

    private func finalizeAndUploadCurrentSegment() {
        guard let writer = assetWriter, writer.status == .writing,
              let url = currentSegmentUrl else { return }

        videoInput?.markAsFinished()

        let index = currentSegmentIndex
        let sid = streamId

        writer.finishWriting {
            guard let sid else { return }
            Task {
                guard let data = try? Data(contentsOf: url) else { return }
                try? await APIClient.shared.uploadSegment(
                    streamId: sid,
                    segmentData: data,
                    segmentIndex: index,
                    duration: self.segmentDuration
                )
                try? FileManager.default.removeItem(at: url)
                await MainActor.run { self.segmentCount += 1 }
            }
        }

        assetWriter = nil
        videoInput = nil
        isWritingSegment = false
        sessionStarted = false
    }

    private func finalizeCurrentSegment() async {
        guard let writer = assetWriter, writer.status == .writing else { return }
        finalizeAndUploadCurrentSegment()
    }

    // MARK: - Helpers

    private func segmentUrl(for index: Int) -> URL {
        let tmp = FileManager.default.temporaryDirectory
        return tmp.appendingPathComponent("segment_\(index).mp4")
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate support

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, ofType type: AVMediaType) {
        guard let writer = assetWriter, writer.status == .writing else { return }

        // Start the asset writer session on the first sample buffer's presentation time
        if !sessionStarted {
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startSession(atSourceTime: pts)
            sessionStarted = true
            isWritingSegment = true
        }

        guard isWritingSegment else { return }

        if type == .video, let input = videoInput, input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }
}

// MARK: - Errors

enum BroadcastError: LocalizedError {
    case noCameraAvailable
    var errorDescription: String? {
        switch self {
        case .noCameraAvailable: return "No camera available on this device."
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension HLSBroadcastService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task { @MainActor in
            self.appendSampleBuffer(sampleBuffer, ofType: .video)
        }
    }
}
