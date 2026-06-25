import Foundation
@preconcurrency import AVFoundation
import AppKit

/// Full ambient awareness manager: camera capture, mic monitoring,
/// motion detection via frame differencing, light level sensing,
/// and ambient state classification.
@MainActor
@Observable
final class AmbientAwarenessManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Published State (MainActor-isolated)

    var cameraAuthorized = false
    var cameraRunning = false
    var currentFrame: NSImage?
    var micAuthorized = false
    var micActive = false
    var micLevel: Float = 0.0
    var micDecibels: Float = -160.0
    var ambientState: AmbientState = .idle
    var ambientLightLevel: Float = 0.0
    var motionLevel: Float = 0.0
    var isAmbientEnabled = false

    // MARK: - Camera (nonisolated — accessed from video queue)

    nonisolated private let captureSession = AVCaptureSession()
    nonisolated private let videoQueue = DispatchQueue(label: "cockpit.ambient.video", qos: .userInteractive)
    nonisolated private let videoOutput = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private var lastFrame: CIImage?
    nonisolated(unsafe) private var frameSkipCounter = 0
    private let motionCheckInterval = 6  // every 6th frame

    // MARK: - Microphone

    private var audioEngine: AVAudioEngine?

    // MARK: - Init

    override init() {
        super.init()
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
    }

    // MARK: - Permissions

    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraAuthorized = true
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorized = granted
            return granted
        default:
            cameraAuthorized = false
            return false
        }
    }

    func requestMicPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            micAuthorized = true
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            micAuthorized = granted
            return granted
        default:
            micAuthorized = false
            return false
        }
    }

    // MARK: - Camera Lifecycle

    func startCamera() async {
        guard cameraAuthorized, !cameraRunning else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .unspecified),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input)
        else {
            captureSession.commitConfiguration()
            return
        }

        captureSession.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]

        guard captureSession.canAddOutput(videoOutput) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(videoOutput)

        captureSession.commitConfiguration()
        captureSession.startRunning()
        cameraRunning = true
    }

    func stopCamera() {
        captureSession.stopRunning()
        cameraRunning = false
        currentFrame = nil
        lastFrame = nil
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)

        // Convert to NSImage for UI
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)

        // Motion detection (every Nth frame)
        frameSkipCounter += 1
        if frameSkipCounter >= motionCheckInterval {
            frameSkipCounter = 0
            if let last = lastFrame {
                let motion = computeMotionDifference(last, ciImage)
                Task { @MainActor in self.motionLevel = motion }
            }
            lastFrame = ciImage
        }

        // Light level from average luminance
        let luminance = computeAverageLuminance(ciImage)

        Task { @MainActor in
            self.currentFrame = nsImage
            self.ambientLightLevel = luminance
            self.updateAmbientState()
        }
    }

    // MARK: - Microphone Lifecycle (AVAudioEngine-based)

    func startMicMonitoring() async {
        guard micAuthorized, !micActive else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input bus 0
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: inputFormat
        ) { [weak self] buffer, _ in
            guard let self else { return }
            let level = self.computeRMS(from: buffer)
            let decibels = 20.0 * log10(max(level, 1e-10))
            let normalized = Float(max(0.0, min(1.0, (decibels + 60.0) / 60.0)))
            Task { @MainActor in
                self.micLevel = normalized
                self.micDecibels = Float(decibels)
            }
        }

        do {
            try engine.start()
            audioEngine = engine
            micActive = true
        } catch {
            print("[AmbientAwarenessManager] Mic engine failed: \(error)")
        }
    }

    func stopMicMonitoring() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        micActive = false
        micLevel = 0
        micDecibels = -160
    }

    // MARK: - Ambient Toggle

    func enableAmbient() async {
        isAmbientEnabled = true
        let camOK = await requestCameraPermission()
        let micOK = await requestMicPermission()
        if camOK { await startCamera() }
        if micOK { await startMicMonitoring() }
    }

    func disableAmbient() {
        isAmbientEnabled = false
        stopCamera()
        stopMicMonitoring()
        ambientState = .idle
        motionLevel = 0
    }

    // MARK: - Audio Analysis

    nonisolated private func computeRMS(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        let samples = channelData[0]
        var sum: Float = 0
        for i in 0..<frameLength {
            let s = samples[i]
            sum += s * s
        }
        return sqrt(sum / Float(frameLength))
    }

    // MARK: - Vision Analysis

    nonisolated private func computeMotionDifference(_ prev: CIImage, _ curr: CIImage) -> Float {
        let small = CIFilter.lanczosScaleTransform()
        small.inputImage = prev
        small.scale = 0.1
        small.aspectRatio = 1.0
        let prevSmall = small.outputImage ?? prev

        small.inputImage = curr
        let currSmall = small.outputImage ?? curr

        let diff = CIFilter.differenceBlendMode()
        diff.inputImage = prevSmall
        diff.backgroundImage = currSmall

        guard let diffImg = diff.outputImage else { return 0 }

        let extent = diffImg.extent
        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: 4)
        let samplePoints = 100
        var changedCount = 0

        for _ in 0..<samplePoints {
            let x = CGFloat.random(in: extent.minX..<extent.maxX)
            let y = CGFloat.random(in: extent.minY..<extent.maxY)
            context.render(diffImg, toBitmap: &bitmap, rowBytes: 4,
                           bounds: CGRect(x: x, y: y, width: 1, height: 1),
                           format: .RGBA8, colorSpace: nil)
            let brightness = Float(bitmap[0]) + Float(bitmap[1]) + Float(bitmap[2])
            if brightness > 90 { changedCount += 1 }
        }

        return Float(changedCount) / Float(samplePoints)
    }

    nonisolated private func computeAverageLuminance(_ image: CIImage) -> Float {
        let areaAvg = CIFilter.areaAverage()
        areaAvg.inputImage = image
        areaAvg.extent = image.extent
        guard let output = areaAvg.outputImage else { return 0 }
        var pixel = [Float](repeating: 0, count: 4)
        let context = CIContext()
        context.render(output, toBitmap: &pixel, rowBytes: 16,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBAf, colorSpace: nil)
        return pixel[0] * 0.299 + pixel[1] * 0.587 + pixel[2] * 0.114
    }

    // MARK: - State Machine (MainActor)

    private func updateAmbientState() {
        guard isAmbientEnabled else {
            ambientState = .idle
            return
        }

        if motionLevel > 0.15 {
            ambientState = .motionDetected
        } else if micLevel > 0.5 {
            ambientState = .noisy
        } else if micLevel > 0.15 && motionLevel > 0.03 {
            ambientState = .conversation
        } else if micLevel > 0.05 || motionLevel > 0.01 {
            ambientState = .active
        } else {
            ambientState = .idle
        }
    }
}

// MARK: - AmbientState

enum AmbientState: String, CaseIterable {
    case idle = "Idle"
    case active = "Active"
    case noisy = "Noisy"
    case motionDetected = "Motion"
    case conversation = "Conversation"

    var color: String {
        switch self {
        case .idle: return "gray"
        case .active: return "cyan"
        case .noisy: return "orange"
        case .motionDetected: return "yellow"
        case .conversation: return "green"
        }
    }

    var icon: String {
        switch self {
        case .idle: return "moon.zzz"
        case .active: return "eye"
        case .noisy: return "speaker.wave.3"
        case .motionDetected: return "figure.walk.motion"
        case .conversation: return "message"
        }
    }
}