//
//  AudioRecordingService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Production Implementation of Audio Recording & Speech Recognition Service.
//

import Foundation
import AVFAudio
import Speech

/// Errors specific to voice recording and speech recognition operations.
public enum VoiceRecordingError: LocalizedError, Sendable {
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case recognizerUnavailable
    case audioEngineError(String)
    case transcriptionError(String)
    case cancelled
    
    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access was denied. Please allow microphone access in Settings."
        case .speechRecognitionPermissionDenied:
            return "Speech recognition permission was denied. Please enable it in Settings."
        case .recognizerUnavailable:
            return "Speech recognizer is not available on this device or for the current locale."
        case .audioEngineError(let msg):
            return "Audio engine failure: \(msg)"
        case .transcriptionError(let msg):
            return "Speech recognition failure: \(msg)"
        case .cancelled:
            return "Voice recording was cancelled."
        }
    }
}

/// Production implementation of AudioRecordingServiceProtocol utilizing AVAudioEngine and SFSpeechRecognizer.
public final class AudioRecordingService: NSObject, AudioRecordingServiceProtocol, @unchecked Sendable {
    
    // MARK: - State
    
    private let lock = NSLock()
    private var _isRecording = false
    private var _audioPower: Float = 0.0
    
    public var isRecording: Bool {
        lock.withLock { _isRecording }
    }
    
    public var audioPower: Float {
        lock.withLock { _audioPower }
    }
    
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var silenceTimer: Task<Void, Never>?
    private let silenceTimeout: TimeInterval = 1.5
    private var hasHeardSpeech = false
    
    // MARK: - Initializer
    
    public init(locale: Locale = Locale(identifier: "en-IN")) {
        super.init()
        self.speechRecognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale.current)
    }
    
    // MARK: - Permissions
    
    public func requestAuthorization() async -> Bool {
        // 1. Speech Recognition Auth
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }
        
        // 2. Microphone Record Permission
        #if os(iOS)
        if #available(iOS 17.0, *) {
            let micGranted = await AVAudioApplication.requestRecordPermission()
            return micGranted
        } else {
            let micGranted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            return micGranted
        }
        #else
        return true
        #endif
    }
    
    // MARK: - Recording Operations
    
    public func startRecording(
        onTranscript: @escaping @Sendable (String) -> Void,
        onPowerChange: @escaping @Sendable (Float) -> Void
    ) async throws {
        // Reset previous state
        await stopRecording()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw VoiceRecordingError.recognizerUnavailable
        }
        
        let authorized = await requestAuthorization()
        guard authorized else {
            throw VoiceRecordingError.speechRecognitionPermissionDenied
        }
        
        lock.withLock {
            _isRecording = true
            _audioPower = 0.0
            hasHeardSpeech = false
        }
        
        do {
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif
            
            let engine = AVAudioEngine()
            self.audioEngine = engine
            
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = true
            // Enforce 100% on-device speech processing to guarantee privacy invariants
            request.requiresOnDeviceRecognition = true
            self.recognitionRequest = request
            
            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
                guard let self = self else { return }
                self.recognitionRequest?.append(buffer)
                
                // Compute audio RMS power for waveform visualization
                let power = self.calculateRMS(buffer: buffer)
                self.lock.withLock {
                    self._audioPower = power
                }
                onPowerChange(power)
            }
            
            engine.prepare()
            try engine.start()
            
            self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    if !transcript.isEmpty {
                        self.lock.withLock {
                            self.hasHeardSpeech = true
                        }
                        onTranscript(transcript)
                        self.restartSilenceTimer()
                    }
                }
                
                if error != nil || result?.isFinal == true {
                    Task {
                        await self.stopRecording()
                    }
                }
            }
            
        } catch {
            await stopRecording()
            throw VoiceRecordingError.audioEngineError(error.localizedDescription)
        }
    }
    
    public func stopRecording() async {
        silenceTimer?.cancel()
        silenceTimer = nil
        
        lock.withLock {
            _isRecording = false
            _audioPower = 0.0
            hasHeardSpeech = false
        }
        
        audioEngine?.stop()
        if let inputNode = audioEngine?.inputNode {
            inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
                #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
    
    // MARK: - Private Helpers
    
    private func restartSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.silenceTimeout * 1_000_000_000))
            if !Task.isCancelled {
                let shouldStop = self.lock.withLock { self.hasHeardSpeech && self._isRecording }
                if shouldStop {
                    await self.stopRecording()
                }
            }
        }
    }
    
    private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        
        var sum: Float = 0.0
        for sample in channelDataArray {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        
        // Normalize RMS (typically 0.0 to 0.5) to a clean 0.0 ... 1.0 power curve
        let normalized = min(max((rms - 0.01) * 3.5, 0.0), 1.0)
        return normalized
    }
}
