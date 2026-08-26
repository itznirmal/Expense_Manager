//
//  AudioRecordingServiceProtocol.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Voice Ingestion Audio Recording & Speech Recognition Service Protocol.
//

import Foundation

/// Service protocol defining audio capture, speech recognition, and live power metering.
public protocol AudioRecordingServiceProtocol: AnyObject, Sendable {
    /// Indicates whether audio recording is currently active.
    var isRecording: Bool { get }
    
    /// Current normalized audio power level (0.0 to 1.0).
    var audioPower: Float { get }
    
    /// Requests microphone and speech recognition permissions.
    /// - Returns: True if all necessary permissions are granted.
    func requestAuthorization() async -> Bool
    
    /// Starts capturing audio and streaming real-time speech transcription and audio power.
    /// - Parameters:
    ///   - onTranscript: Callback invoked when new transcription tokens arrive.
    ///   - onPowerChange: Callback invoked when audio power metering updates.
    func startRecording(
        onTranscript: @escaping @Sendable (String) -> Void,
        onPowerChange: @escaping @Sendable (Float) -> Void
    ) async throws
    
    /// Stops audio capture and speech recognition.
    func stopRecording() async
}
