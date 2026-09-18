//
//  SplitTransactionView.swift
//  ExpenseManager
//
//  Split one expense/income into multiple category lines (top forum request).
//

import SwiftUI

public struct SplitTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    public let transaction: TransactionCandidate
    public var onCompleted: (() -> Void)? = nil
    
    @State private var lines: [EditableSplitLine] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    public init(transaction: TransactionCandidate, onCompleted: (() -> Void)? = nil) {
        self.transaction = transaction
        self.onCompleted = onCompleted
        let half = (transaction.amount / 2).rounded(0, .plain)
        let remainder = transaction.amount - half
        _lines = State(initialValue: [
            EditableSplitLine(
                amountText: NSDecimalNumber(decimal: half).stringValue,
                categoryName: transaction.categorySuggestion ?? "",
                merchantName: transaction.merchantName
            ),
            EditableSplitLine(
                amountText: NSDecimalNumber(decimal: remainder).stringValue,
                categoryName: "",
                merchantName: transaction.merchantName
            )
        ])
    }
    
    private var parsedLines: [TransactionSplitLine] {
        lines.compactMap { line in
            guard let amount = Decimal(string: line.amountText.replacingOccurrences(of: ",", with: "")),
                  amount > 0 else { return nil }
            return TransactionSplitLine(
                amount: amount,
                categoryName: line.categoryName.isEmpty ? nil : line.categoryName,
                merchantName: line.merchantName,
                notes: line.notes.isEmpty ? nil : line.notes
            )
        }
    }
    
    private var splitTotal: Decimal {
        parsedLines.reduce(.zero) { $0 + $1.amount }
    }
    
    private var remaining: Decimal {
        abs(transaction.amount) - splitTotal
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Original") {
                        Text(CurrencyFormatter.shared.format(amount: transaction.amount, currencyCode: transaction.currencyCode))
                            .font(Typography.headline)
                    }
                    LabeledContent("Allocated") {
                        Text(CurrencyFormatter.shared.format(amount: splitTotal, currencyCode: transaction.currencyCode))
                    }
                    LabeledContent("Remaining") {
                        Text(CurrencyFormatter.shared.format(amount: remaining, currencyCode: transaction.currencyCode))
                            .foregroundStyle(remaining == .zero ? ColorTokens.incomeAccent : ColorTokens.criticalAccent)
                    }
                } header: {
                    Text("Balance Check")
                } footer: {
                    Text("Split amounts must add up exactly to the original transaction. Common for grocery + household or shared expenses.")
                }
                
                ForEach($lines) { $line in
                    Section("Line") {
                        TextField("Amount", text: $line.amountText)
                            .keyboardType(.decimalPad)
                        TextField("Category", text: $line.categoryName)
                        TextField("Merchant", text: $line.merchantName)
                        TextField("Notes", text: $line.notes)
                    }
                }
                
                Section {
                    Button {
                        lines.append(EditableSplitLine(
                            amountText: remaining > 0 ? "\(remaining)" : "0",
                            categoryName: "",
                            merchantName: transaction.merchantName
                        ))
                    } label: {
                        Label("Add Split Line", systemImage: "plus.circle")
                    }
                    
                    if lines.count > 2 {
                        Button(role: .destructive) {
                            lines.removeLast()
                        } label: {
                            Label("Remove Last Line", systemImage: "minus.circle")
                        }
                    }
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(ColorTokens.criticalAccent)
                            .font(Typography.caption)
                    }
                }
            }
            .navigationTitle("Split Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Split") {
                        Task { await saveSplit() }
                    }
                    .disabled(isSaving || remaining != .zero || parsedLines.count < 2)
                }
            }
        }
    }
    
    private func saveSplit() async {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await container.transactionService.splitTransaction(
                id: transaction.id.uuidString,
                splits: parsedLines
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            appState.showToast(title: "Transaction Split", message: "\(parsedLines.count) lines created", type: .success)
            onCompleted?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

private struct EditableSplitLine: Identifiable {
    let id = UUID()
    var amountText: String
    var categoryName: String
    var merchantName: String
    var notes: String = ""
}

private extension Decimal {
    func rounded(_ scale: Int, _ mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }
}
