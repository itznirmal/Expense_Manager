//
//  InputSource.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Transaction Ingestion Origin Channels.
//

import Foundation

/// Represents the entry channel through which a transaction was captured.
public enum InputSource: String, Codable, CaseIterable, Sendable {
    case manual
    case smartText
    case voice
    case siri
    case sms
    case shortcut
    case receipt
    case screenshot
    case bulkImport
    
    public var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .smartText: return "Smart Text"
        case .voice: return "Voice"
        case .siri: return "Siri"
        case .sms: return "SMS Automation"
        case .shortcut: return "Shortcuts"
        case .receipt: return "Receipt Scan"
        case .screenshot: return "Screenshot"
        case .bulkImport: return "Bulk Import"
        }
    }
    
    public var iconName: String {
        switch self {
        case .manual: return "square.and.pencil"
        case .smartText: return "sparkles"
        case .voice: return "mic.fill"
        case .siri: return "waveform"
        case .sms: return "message.badge.filled.fill"
        case .shortcut: return "link"
        case .receipt: return "doc.text.viewfinder"
        case .screenshot: return "photo"
        case .bulkImport: return "square.and.arrow.down"
        }
    }
}
