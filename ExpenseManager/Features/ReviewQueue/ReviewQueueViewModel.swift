//
//  ReviewQueueViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Observable ViewModel for Confidence Review Queue Management.
//

import SwiftUI
import Observation

@Observable
@MainActor
public final class ReviewQueueViewModel {
    
    public enum FilterTier: String, CaseIterable, Identifiable, Sendable {
        case all = "All"
        case medium = "Medium"
        case low = "Low"
        
        public var id: String { rawValue }
    }
    
    // MARK: - State Properties
    
    public var queuedCandidates: [TransactionCandidate] = []
    public var selectedFilter: FilterTier = .all
    public var candidateToEdit: TransactionCandidate? = nil
    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    
    public init(initialCandidates: [TransactionCandidate] = []) {
        self.queuedCandidates = initialCandidates
    }
    
    // MARK: - Computed Properties
    
    public var filteredCandidates: [TransactionCandidate] {
        switch selectedFilter {
        case .all:
            return queuedCandidates
        case .medium:
            return queuedCandidates.filter { $0.confidence.tier == .medium }
        case .low:
            return queuedCandidates.filter { $0.confidence.tier == .low }
        }
    }
    
    public var highConfidenceEligibleCount: Int {
        queuedCandidates.filter { $0.confidence.value >= 0.85 }.count
    }
    
    // MARK: - Actions
    
    public func loadQueue(container: DependencyContainer) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch recent transactions that need review or were ingested via automated streams
            let recents = try await container.transactionService.fetchRecentTransactions(limit: 50)
            let reviewItems = recents.filter { $0.needsReview || $0.confidence.requiresReview }
            
            if !reviewItems.isEmpty {
                self.queuedCandidates = reviewItems
            } else if queuedCandidates.isEmpty {
                // Pre-populate realistic sample pending items for first-launch exploration
                self.queuedCandidates = Self.defaultSampleReviewQueue()
            }
        } catch {
            self.errorMessage = "Failed to load review queue: \(error.localizedDescription)"
        }
    }
    
    public func acceptCandidate(
        _ candidate: TransactionCandidate,
        container: DependencyContainer,
        appState: AppState
    ) async {
        var accepted = candidate
        accepted.needsReview = false
        
        do {
            try await container.transactionService.createTransaction(accepted)
            queuedCandidates.removeAll { $0.id == candidate.id }
            appState.pendingReviewCount = queuedCandidates.count
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            appState.showToast(
                title: "Accepted Transaction",
                message: "\(CurrencyFormatter.shared.format(amount: candidate.amount)) • \(candidate.merchantName)",
                type: .success
            )
        } catch {
            errorMessage = "Failed to accept candidate: \(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    public func acceptAllEligible(container: DependencyContainer, appState: AppState) async {
        let eligible = queuedCandidates.filter { $0.confidence.value >= 0.85 }
        for candidate in eligible {
            await acceptCandidate(candidate, container: container, appState: appState)
        }
    }
    
    public func discardCandidate(_ candidate: TransactionCandidate, appState: AppState) {
        queuedCandidates.removeAll { $0.id == candidate.id }
        appState.pendingReviewCount = queuedCandidates.count
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        appState.showToast(
            title: "Transaction Discarded",
            message: "\(candidate.merchantName.isEmpty ? "Unknown" : candidate.merchantName)",
            type: .info
        )
    }
    
    public func startEditing(_ candidate: TransactionCandidate) {
        self.candidateToEdit = candidate
    }
    
    public static func defaultSampleReviewQueue() -> [TransactionCandidate] {
        [
            TransactionCandidate(
                id: UUID(),
                type: .expense,
                amount: Decimal(1250),
                currencyCode: "INR",
                merchantName: "AMZN MKTP IN",
                categorySuggestion: "Shopping",
                accountSuggestion: nil,
                paymentMethod: .creditCard,
                transactionDate: Date().addingTimeInterval(-3600 * 4),
                notes: "UPI/482019283741 AMZN MKTP IN paid",
                source: .sms,
                confidence: ConfidenceScore(0.72),
                needsReview: true,
                warnings: ["Unassigned bank/payment account"]
            ),
            TransactionCandidate(
                id: UUID(),
                type: .expense,
                amount: Decimal(450),
                currencyCode: "INR",
                merchantName: "CHAIPOI VENDOR",
                categorySuggestion: nil,
                accountSuggestion: "HDFC Bank",
                paymentMethod: .upi,
                transactionDate: Date().addingTimeInterval(-3600 * 18),
                notes: "Paid to chaipoi@okhdfcbank",
                source: .sms,
                confidence: ConfidenceScore(0.68),
                needsReview: true,
                warnings: ["Uncategorized transaction"]
            ),
            TransactionCandidate(
                id: UUID(),
                type: .expense,
                amount: Decimal(58000),
                currencyCode: "INR",
                merchantName: "Apple Store",
                categorySuggestion: "Electronics",
                accountSuggestion: "HDFC Credit Card",
                paymentMethod: .creditCard,
                transactionDate: Date().addingTimeInterval(-3600 * 26),
                notes: "Purchased Apple Store Mumbai",
                source: .ocr,
                confidence: ConfidenceScore(0.88),
                needsReview: true,
                warnings: ["High value transaction requires confirmation"]
            )
        ]
    }
}
