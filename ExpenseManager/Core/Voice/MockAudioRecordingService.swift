//
//  MockAudioRecordingService.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  In-Memory Mock Audio Recording Service for Previews & Unit Tests.
//

import Foundation

/// In-memory mock audio recording service allowing deterministic simulation of speech streams and metering.
public final class MockAudioRecordingService: AudioRecordingServiceProtocol, @unchecked Sendable {
    
    private let lock = NSLock()
    private var _isRecording = false
    private var _audioPower: Float = 0.0
    
    public var isRecording: Bool {
        lock.withLock { _isRecording }
    }
    
    public var audioPower: Float {
        lock.withLock { _audioPower }
    }
    
    public var shouldGrantAuthorization: Bool = true
    public var simulatedTranscripts: [String] = [
        "Swiggy",
        "Swiggy 540",
        "Swiggy 540 rupees from HDFC",
        "Swiggy 540 rupees from HDFC Bank today"
    ]
    public var simulatedFinalTranscript: String = "Swiggy 540 rupees from HDFC Bank today"
    public var simulatedPowerSequence: [Float] = [0.15, 0.4, 0.75, 0.9, 0.6, 0.3, 0.05]
    public var errorToThrow: Error? = nil
    
    private var simulationTask: Task<Void, Never>?
    
    public init(
        shouldGrantAuthorization: Bool = true,
        simulatedFinalTranscript: String = "Swiggy 540 rupees from HDFC Bank today"
    ) {
        self.shouldGrantAuthorization = shouldGrantAuthorization
        self.simulatedFinalTranscript = simulatedFinalTranscript
    }
    
    public func requestAuthorization() async -> Bool {
        return shouldGrantAuthorization
    }
    
    public func startRecording(
        onTranscript: @escaping @Sendable (String) -> Void,
        onPowerChange: @escaping @Sendable (Float) -> Void
    ) async throws {
        if let error = errorToThrow {
            throw error
        }
        
        guard shouldGrantAuthorization else {
            throw VoiceRecordingError.microphonePermissionDenied
        }
        
        lock.withLock {
            _isRecording = true
            _audioPower = 0.2
        }
        
        simulationTask?.cancel()
        simulationTask = Task { [weak self] in
            guard let self = self else { return }
            
            // Stream progressive transcripts
            for transcript in self.simulatedTranscripts {
                try? await Task.sleep(nanoseconds: 120_000_000) // 120ms
                if Task.isCancelled { return }
                onTranscript(transcript)
                
                // Random power modulation
                let power = self.simulatedPowerSequence.randomElement() ?? 0.5
                self.lock.withLock { self._audioPower = power }
                onPowerChange(power)
            }
            
            // Final transcript
            onTranscript(self.simulatedFinalTranscript)
            
            // Simulate silence
            try? await Task.sleep(nanoseconds: 250_000_000)
            if !Task.isCancelled {
                await self.stopRecording()
            }
        }
    }
    
    public func stopRecording() async {
        simulationTask?.cancel()
        simulationTask = nil
        
        lock.withLock {
            _isRecording = false
            _audioPower = 0.0
        }
    }
}
