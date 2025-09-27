import Foundation
import Speech
import Combine

@MainActor
class SpeechRecognizerService: ObservableObject {
    
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var isAvailable: Bool = false
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        checkPermissionsAndAvailability()
    }

    private func checkPermissionsAndAvailability() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            // Use the modern API for requesting microphone permission.
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.isAvailable = (authStatus == .authorized) && granted
                    if !self.isAvailable {
                        print("Speech recognition or microphone permission was denied.")
                    }
                }
            }
        }
    }

    func startRecording() {
        guard isAvailable, !isRecording else { return }
        
        transcript = ""
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode:.measurement, options:.duckOthers)
            try audioSession.setActive(true, options:.notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup error: \(error.localizedDescription)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        recognitionTask = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                self.transcript = result.bestTranscription.formattedString
            }
            
            if error != nil || result?.isFinal == true {
                self.stopRecording()
            }
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            print("Audio engine start error: \(error.localizedDescription)")
            stopRecording()
        }
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Audio session deactivation error: \(error.localizedDescription)")
        }
    }
}