//
//  ToastMessage.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  App-level Toast Notification Model.
//

import Foundation

/// Defines a transient notification message displayed to the user.
public struct ToastMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let message: String?
    public let type: ToastType
    public let duration: TimeInterval
    
    public enum ToastType: Sendable {
        case info
        case success
        case warning
        case error
        
        public var iconName: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }
    
    public init(
        id: UUID = UUID(),
        title: String,
        message: String? = nil,
        type: ToastType = .info,
        duration: TimeInterval = 3.0
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.type = type
        self.duration = duration
    }
}
