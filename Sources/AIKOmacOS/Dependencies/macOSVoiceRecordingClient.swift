#if os(macOS)
    import AppCore
    import AVFoundation
    import ComposableArchitecture
    import Foundation

    // MARK: - macOS Voice Recording Client

    public extension VoiceRecordingClient {
        static var macOSLive: Self {
            let recorder = MacOSAudioRecorder()

            return Self(
                checkPermissions: {
                    // macOS handles permissions differently - generally granted by default
                    true
                },
                requestPermissions: {
                    // macOS doesn't require explicit permission requests for audio recording
                    true
                },
                startRecording: {
                    try await recorder.startRecording()
                },
                stopRecording: {
                    try await recorder.stopRecording()
                },
                cancelRecording: {
                    try await recorder.cancelRecording()
                }
            )
        }
    }

    // MARK: - macOS Audio Recorder Implementation

    private final class MacOSAudioRecorder: NSObject, @unchecked Sendable {
        private var audioRecorder: AVAudioRecorder?
        private let audioEngine = AVAudioEngine()
        private var audioFileURL: URL?

        override init() {
            super.init()
        }

        func startRecording() async throws {
            // Create audio file for recording
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            audioFileURL = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]

            guard let audioFileURL else { throw VoiceRecordingError.recordingFailed }
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()

            // Start audio engine for monitoring
            audioEngine.prepare()
            try audioEngine.start()
        }

        func stopRecording() async throws -> String {
            audioRecorder?.stop()
            audioEngine.stop()

            // Clean up
            audioRecorder = nil

            // On macOS, we return a placeholder since Speech framework isn't available
            // In a real implementation, you might integrate with a third-party service
            // or use a different transcription approach
            return "Voice recording completed. Transcription requires manual processing on macOS."
        }

        func cancelRecording() async throws {
            audioRecorder?.stop()
            audioEngine.stop()

            // Delete the recording file if it exists
            if let audioFileURL {
                try? FileManager.default.removeItem(at: audioFileURL)
            }

            // Clean up
            audioRecorder = nil
            audioFileURL = nil
        }
    }#endif
