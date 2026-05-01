import Foundation
import AVFoundation

@Observable
final class AudioRecorderService: NSObject, AVAudioRecorderDelegate {
    static let shared = AudioRecorderService()
    
    private var audioRecorder: AVAudioRecorder?
    private(set) var isRecording = false
    private(set) var lastRecordedURL: URL?
    
    private override init() {
        super.init()
    }
    
    func startRecording() async throws {
        let session = AVAudioSession.sharedInstance()
        
        // Use a more compatible way to request permission that handles all iOS versions reliably
        let granted = await withCheckedContinuation { continuation in
            session.requestRecordPermission { response in
                continuation.resume(returning: response)
            }
        }
        
        guard granted else {
            throw NSError(domain: "AudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone access denied"])
        }
        
        try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
        try session.setActive(true)
        
        // Unique filename to avoid conflicts and potential crashes on file access
        let filename = "recording_\(UUID().uuidString).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.prepareToRecord() // Prepare before recording
        audioRecorder?.record()
        
        await MainActor.run {
            isRecording = true
            lastRecordedURL = url
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        Task { @MainActor in
            isRecording = false
        }
    }
    
    func getRecordingData() -> Data? {
        guard let url = lastRecordedURL else { return nil }
        return try? Data(contentsOf: url)
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            isRecording = false
            if !flag {
                lastRecordedURL = nil
            }
        }
    }
}
