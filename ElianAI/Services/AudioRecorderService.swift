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
        
        // Request permission explicitly
        if session.recordPermission == .undetermined {
            await session.requestRecordPermission()
        }
        
        guard session.recordPermission == .granted else {
            throw NSError(domain: "AudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone access denied"])
        }
        
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()
        isRecording = true
        lastRecordedURL = url
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }
    
    func getRecordingData() -> Data? {
        guard let url = lastRecordedURL else { return nil }
        return try? Data(contentsOf: url)
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        if !flag {
            lastRecordedURL = nil
        }
    }
}
