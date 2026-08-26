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
        queuedCandidates.filter { $0.confidence.value >= 0.90 }.count
    }
    
    // MARK: - Actions
    
    public func loadQueue(container: DependencyContainer) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            self.queuedCandidates = try await container.transactionService.fetchPendingReviewTransactions()
        } catch {
            self.errorMessage = "Failed to load review queue: \(error.localizedDescription)"
        }
    }
    
    public func acceptCandidate(
        _ candidate: TransactionCandidate,
        container: DependencyContainer,
        appState: AppState
    ) async {
        do {
            try await container.transactionService.acceptTransaction(id: candidate.id.uuidString)
            
            queuedCandidates.removeAll { $0.id == candidate.id }
            appState.pendingReviewCount = queuedCandidates.count
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            appState.showToast(
                title: "Accepted Transaction",
                message: "\(CurrencyFormatter.shared.format(amount: candidate.amount)) – \(candidate.merchantName)",
                type: .success
            )
        } catch {
            errorMessage = "Failed to accept candidate: \(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    public func acceptAllEligible(container: DependencyContainer, appState: AppState) async {
        let eligible = queuedCandidates.filter { $0.confidence.value >= 0.90 }
        for candidate in eligible {
            await acceptCandidate(candidate, container: container, appState: appState)
        }
    }
    
    public func discardCandidate(
        _ candidate: TransactionCandidate,
        container: DependencyContainer,
        appState: AppState
    ) async {
        do {
            try await container.transactionService.deleteTransaction(id: candidate.id.uuidString)
            queuedCandidates.removeAll { $0.id == candidate.id }
            appState.pendingReviewCount = queuedCandidates.count
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            appState.showToast(
                title: "Transaction Discarded",
                message: "\(candidate.merchantName.isEmpty ? "Unknown" : candidate.merchantName)",
                type: .info
            )
        } catch {
            self.errorMessage = "Failed to discard candidate: \(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    public func startEditing(_ candidate: TransactionCandidate) {
        self.candidateToEdit = candidate
    }
    

}
