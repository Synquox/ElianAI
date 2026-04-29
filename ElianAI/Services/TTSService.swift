import Foundation
import AVFoundation

@Observable
final class TTSService {
    var isSpeaking = false
    var isPaused = false
    var currentProgress: Double = 0.0
    
    private let delegate: TTSDelegate
    private let synthesizer = AVSpeechSynthesizer()
    
    init() {
        delegate = TTSDelegate()
        synthesizer.delegate = delegate
        
        // Forward delegate state to observable properties
        delegate.onStateChange = { [weak self] speaking, paused, progress in
            self?.isSpeaking = speaking
            self?.isPaused = paused
            self?.currentProgress = progress
        }
        
        // Setup audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category.")
        }
    }
    
    func speak(text: String, language: String = "en-US") {
        stop()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        synthesizer.speak(utterance)
    }
    
    func pause() {
        if synthesizer.isSpeaking && !synthesizer.isPaused {
            synthesizer.pauseSpeaking(at: .immediate)
        }
    }
    
    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }
    
    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    func togglePlayPause(text: String) {
        if isSpeaking {
            if isPaused {
                resume()
            } else {
                pause()
            }
        } else {
            speak(text: text)
        }
    }
}

// MARK: - Delegate (NSObject-based, separate from @Observable)

private final class TTSDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onStateChange: ((_ speaking: Bool, _ paused: Bool, _ progress: Double) -> Void)?
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        onStateChange?(true, false, 0.0)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        onStateChange?(true, true, 0.0)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        onStateChange?(true, false, 0.0)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onStateChange?(false, false, 0.0)
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let total = Double(utterance.speechString.count)
        let current = Double(characterRange.location + characterRange.length)
        let progress = current / total
        onStateChange?(true, false, progress)
    }
}
