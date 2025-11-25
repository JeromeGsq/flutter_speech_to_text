import Flutter
import UIKit
import Speech
import AVFoundation

public class SpeechToTextPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    private var eventSink: FlutterEventSink?
    private var lastTranscript: String = ""
    private var lastConfidence: Double = 0.0
    private var isManuallyStopped: Bool = false
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.dbkable.speech_to_text/methods",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "com.dbkable.speech_to_text/events",
            binaryMessenger: registrar.messenger()
        )
        
        let instance = SpeechToTextPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    // MARK: - FlutterStreamHandler
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    // MARK: - FlutterPlugin
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            guard let args = call.arguments as? [String: Any],
                  let language = args["language"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Language is required", details: nil))
                return
            }
            start(language: language, result: result)
            
        case "stop":
            stop(result: result)
            
        case "requestPermissions":
            requestPermissions(result: result)
            
        case "isAvailable":
            isAvailable(result: result)
            
        case "openSettings":
            openSettings(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Public Methods
    
    private func requestPermissions(result: @escaping FlutterResult) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            result(granted)
                        }
                    }
                case .denied, .restricted, .notDetermined:
                    result(false)
                @unknown default:
                    result(false)
                }
            }
        }
    }
    
    private func isAvailable(result: @escaping FlutterResult) {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        let recognizerAvailable = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) != nil
        let available = (authStatus == .authorized || authStatus == .notDetermined) && recognizerAvailable
        result(available)
    }
    
    private func openSettings(result: @escaping FlutterResult) {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            result(false)
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl) { success in
                result(success)
            }
        } else {
            result(false)
        }
    }
    
    private func start(language: String, result: @escaping FlutterResult) {
        lastTranscript = ""
        lastConfidence = 0.0
        isManuallyStopped = false
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Speech recognition not authorized", details: nil))
            return
        }
        
        let locale = Locale(identifier: language)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            result(FlutterError(code: "NOT_AVAILABLE", message: "Speech recognizer not available", details: nil))
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                result(FlutterError(code: "REQUEST_FAILED", message: "Unable to create recognition request", details: nil))
                return
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] recognitionResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    if !self.isManuallyStopped {
                        let errorCode = self.mapErrorCode(from: error)
                        let errorMessage = self.mapErrorMessage(from: error)
                        self.sendEvent(type: "onSpeechError", data: [
                            "code": errorCode,
                            "message": errorMessage
                        ])
                    }
                    return
                }
                
                if let recognitionResult = recognitionResult {
                    let transcript = recognitionResult.bestTranscription.formattedString
                    let isFinal = recognitionResult.isFinal
                    let confidence = self.getConfidence(from: recognitionResult)
                    
                    self.lastTranscript = transcript
                    self.lastConfidence = confidence
                    
                    self.sendEvent(type: "onSpeechResult", data: [
                        "transcript": transcript,
                        "isFinal": isFinal,
                        "confidence": confidence
                    ])
                    
                    if isFinal && !self.isManuallyStopped {
                        self.stopRecognition()
                        self.sendEvent(type: "onSpeechEnd", data: [:])
                    }
                }
            }
            
            result(nil)
            
        } catch {
            result(FlutterError(code: "START_FAILED", message: "Failed to start recognition: \(error.localizedDescription)", details: nil))
        }
    }
    
    private func stop(result: @escaping FlutterResult) {
        isManuallyStopped = true
        
        // Stop audio engine first
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // End audio input - this signals no more audio is coming
        recognitionRequest?.endAudio()
        
        // Use finish() instead of cancel() to get the final result with confidence
        recognitionTask?.finish()
        
        // The recognition callback will receive the final result
        // We wait a short moment for the final result to come through
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            // If we still have a transcript but didn't get a final result, send it
            if !self.lastTranscript.isEmpty {
                self.sendEvent(type: "onSpeechResult", data: [
                    "transcript": self.lastTranscript,
                    "isFinal": true,
                    "confidence": self.lastConfidence
                ])
            }
            
            self.sendEvent(type: "onSpeechEnd", data: [:])
            self.cleanupRecognition()
        }
        
        result(nil)
    }
    
    // MARK: - Private Methods
    
    private func cleanupRecognition() {
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    private func stopRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        cleanupRecognition()
    }
    
    private func getConfidence(from result: SFSpeechRecognitionResult) -> Double {
        let segments = result.bestTranscription.segments
        guard !segments.isEmpty else {
            return 0.0
        }
        
        // Calculate average confidence across all segments with non-zero confidence
        let confidences = segments.map { Double($0.confidence) }.filter { $0 > 0 }
        
        if confidences.isEmpty {
            // For partial results, confidence is often 0.0
            // Return 0.0 to indicate confidence not yet available
            return 0.0
        }
        
        return confidences.reduce(0, +) / Double(confidences.count)
    }
    
    private func mapErrorCode(from error: Error) -> String {
        let nsError = error as NSError
        
        if nsError.domain == "kLSRErrorDomain" {
            switch nsError.code {
            case 1: return "PERMISSION_DENIED"
            case 2: return "NOT_AVAILABLE"
            case 4: return "NETWORK_ERROR"
            case 7: return "RECOGNIZER_BUSY"
            default: return "UNKNOWN_ERROR"
            }
        }
        
        if nsError.domain == NSOSStatusErrorDomain || nsError.domain == AVFoundationErrorDomain {
            return "AUDIO_ERROR"
        }
        
        return "UNKNOWN_ERROR"
    }
    
    private func mapErrorMessage(from error: Error) -> String {
        let nsError = error as NSError
        
        if nsError.domain == "kLSRErrorDomain" {
            switch nsError.code {
            case 1: return "Insufficient permissions"
            case 2: return "Speech recognizer not available"
            case 4: return "Network error"
            case 7: return "Recognizer busy"
            default: return "Unknown error"
            }
        }
        
        if nsError.domain == NSOSStatusErrorDomain || nsError.domain == AVFoundationErrorDomain {
            return "Audio recording error"
        }
        
        return "Unknown error"
    }
    
    private func sendEvent(type: String, data: [String: Any]) {
        DispatchQueue.main.async {
            self.eventSink?([
                "type": type,
                "data": data
            ])
        }
    }
}

