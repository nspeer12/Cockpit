import Foundation
import Speech
import AVFoundation

/// Manages JARVIS voice command mode — continuous speech recognition with wake word detection
/// and text-to-speech synthesis for spoken responses.
@MainActor
@Observable
final class JarvisController: NSObject, SFSpeechRecognitionTaskDelegate, AVSpeechSynthesizerDelegate {

    // MARK: - Published State

    private(set) var isListening = false
    private(set) var isSpeaking = false
    var jarvisActive = false
    var currentTranscript = ""
    var responseText = ""
    var wakeWordDetected = false
    var transcriptHistory: [TranscriptEntry] = []
    var statusMessage = ""

    // Callback when a recognized command (after wake word) is finalized
    var onCommandRecognized: ((String) -> Void)?

    // MARK: - Speech Recognition

    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var wakeWordBuffer: String = ""
    private var commandBuffer: String = ""
    private var isGatheringCommand = false
    private var silenceTimer: Timer?
    private let silenceTimeout: TimeInterval = 2.0

    // MARK: - Speech Synthesis

    private let synthesizer = AVSpeechSynthesizer()
    private var speechQueue: [String] = []

    // MARK: - Init

    override init() {
        super.init()
        synthesizer.delegate = self
        requestSpeechAuthorization()
    }

    // MARK: - Permissions

    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    self?.statusMessage = ""
                case .denied, .restricted:
                    self?.statusMessage = "Speech recognition not authorized"
                case .notDetermined:
                    self?.statusMessage = "Speech recognition pending authorization"
                @unknown default:
                    self?.statusMessage = "Unknown speech authorization status"
                }
            }
        }
    }

    // MARK: - JARVIS Toggle

    func toggleJarvisMode() {
        if jarvisActive {
            stopListening()
            jarvisActive = false
            wakeWordDetected = false
            isGatheringCommand = false
            commandBuffer = ""
            currentTranscript = ""
            statusMessage = "JARVIS deactivated"
        } else {
            jarvisActive = true
            statusMessage = "JARVIS activated — listening for 'Hey Jarvis'"
            startListening()
        }
    }

    // MARK: - Listening

    func startListening() {
        guard !isListening else { return }

        // Stop any existing audio
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            statusMessage = "Unable to create recognition request"
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            statusMessage = "Audio engine start failed: \(error.localizedDescription)"
            return
        }

        isListening = true
        statusMessage = "Listening..."

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, delegate: self)
    }

    func stopListening() {
        isListening = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    // MARK: - SFSpeechRecognitionTaskDelegate

    nonisolated func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        Task { @MainActor in
            self.statusMessage = "Speech detected..."
        }
    }

    nonisolated func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        let text = transcription.formattedString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.currentTranscript = text

            if self.isGatheringCommand {
                // We're in command mode — extend the command buffer
                self.commandBuffer = text
                self.statusMessage = "Command: \"\(text)\""
                self.resetSilenceTimer()
            } else {
                // Check for wake word
                if self.containsWakeWord(text) {
                    self.wakeWordDetected = true
                    self.isGatheringCommand = true
                    self.commandBuffer = ""
                    self.statusMessage = "Wake word detected — listening for command..."
                    self.resetSilenceTimer()
                } else {
                    self.statusMessage = "Listening..."
                }
            }
        }
    }

    nonisolated func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        let text = recognitionResult.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)

        Task { @MainActor [weak self] in
            guard let self = self else { return }

            self.transcriptHistory.append(TranscriptEntry(
                text: text,
                isCommand: self.isGatheringCommand && self.wakeWordDetected,
                timestamp: Date()
            ))

            // Trim transcript history to last 50 entries
            if self.transcriptHistory.count > 50 {
                self.transcriptHistory.removeFirst(self.transcriptHistory.count - 50)
            }

            // If we were gathering a command, deliver it
            if self.isGatheringCommand && self.wakeWordDetected && !text.isEmpty {
                let command = text
                self.isGatheringCommand = false
                self.wakeWordDetected = false
                self.commandBuffer = ""
                self.silenceTimer?.invalidate()
                self.silenceTimer = nil

                self.statusMessage = "Command received: \"\(command)\""
                self.onCommandRecognized?(command)

                // After delivering command, start listening for wake word again
                self.currentTranscript = ""
                self.statusMessage = "Listening for 'Hey Jarvis'..."
            }
        }
    }

    nonisolated func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
        Task { @MainActor in
            // Audio buffer finished — recognition continues with partial results
        }
    }

    nonisolated func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        Task { @MainActor in
            self.isListening = false
        }
    }

    nonisolated func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        Task { @MainActor in
            if !successfully {
                self.isGatheringCommand = false
                self.wakeWordDetected = false

                if self.jarvisActive {
                    // Restart listening on failure (e.g., timeout) with debounce
                    self.statusMessage = "Recognition ended — restarting..."
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if self.jarvisActive && !self.isListening {
                        self.startListening()
                    }
                }
            }
        }
    }

    // MARK: - Wake Word Detection

    private func containsWakeWord(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        return lower.contains("hey jarvis") || lower.hasSuffix("jarvis") || lower == "jarvis"
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil

        guard isGatheringCommand else { return }

        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.isGatheringCommand && !self.commandBuffer.isEmpty {
                    let command = self.commandBuffer
                    self.isGatheringCommand = false
                    self.wakeWordDetected = false
                    self.commandBuffer = ""

                    self.statusMessage = "Command final: \"\(command)\""
                    self.onCommandRecognized?(command)

                    self.currentTranscript = ""
                    self.statusMessage = "Listening for 'Hey Jarvis'..."
                } else if self.isGatheringCommand && self.commandBuffer.isEmpty {
                    // No command spoken after wake word — go back to wake word mode
                    self.isGatheringCommand = false
                    self.wakeWordDetected = false
                    self.statusMessage = "No command detected — listening for 'Hey Jarvis'..."
                }
            }
        }
    }

    // MARK: - Text-to-Speech

    func speak(_ text: String) {
        guard !text.isEmpty else { return }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.pitchMultiplier = 0.95
        utterance.volume = 0.85

        // Prefer Daniel (British male), fall back to system default
        if let danielVoice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.en-GB.Daniel") {
            utterance.voice = danielVoice
        } else if let enhancedDaniel = AVSpeechSynthesisVoice(identifier: "com.apple.voice.enhanced.en-GB.Daniel") {
            utterance.voice = enhancedDaniel
        }

        responseText = text
        isSpeaking = true

        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.responseText = ""
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

// MARK: - Transcript Entry

struct TranscriptEntry: Identifiable {
    let id = UUID()
    let text: String
    let isCommand: Bool
    let timestamp: Date
}