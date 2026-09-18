//
//  StatementImportView.swift
//  ExpenseManager
//
//  Bank statement CSV import UI — top forum request for sync-less markets.
//

import SwiftUI
import UniformTypeIdentifiers

public struct StatementImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var showFilePicker = false
    @State private var previewRows: [StatementImportRow] = []
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var accountHint: String = ""
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Import bank CSV/Excel exports when Shortcuts SMS misses history. Columns detected automatically: Date, Amount, Merchant/Narration, Debit/Credit.")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)
                    
                    TextField("Account hint (optional)", text: $accountHint)
                        .textInputAutocapitalization(.words)
                    
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Choose CSV File", systemImage: "doc.badge.plus")
                    }
                }
                
                if !previewRows.isEmpty {
                    Section("Preview (\(previewRows.count) rows)") {
                        ForEach(previewRows.prefix(20)) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(row.merchant)
                                        .font(Typography.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(CurrencyFormatter.shared.format(amount: row.amount, currencyCode: CurrencyFormatter.defaultCurrencyCode))
                                        .foregroundStyle(row.type == .income ? ColorTokens.incomeAccent : ColorTokens.expenseAccent)
                                }
                                Text(row.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(Typography.caption)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                        if previewRows.count > 20 {
                            Text("…and \(previewRows.count - 20) more")
                                .font(Typography.caption)
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                    
                    Section {
                        Button {
                            Task { await runImport() }
                        } label: {
                            if isImporting {
                                ProgressView()
                            } else {
                                Label("Import \(previewRows.count) Transactions", systemImage: "square.and.arrow.down.fill")
                            }
                        }
                        .disabled(isImporting)
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
            .navigationTitle("Import Statement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText, .plainText, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    loadFile(url)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func loadFile(_ url: URL) {
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) else {
                errorMessage = "Could not read file as text."
                return
            }
            previewRows = try container.statementImportService.parseCSV(
                text,
                defaultAccountHint: accountHint.isEmpty ? nil : accountHint
            )
            errorMessage = nil
        } catch {
            previewRows = []
            errorMessage = error.localizedDescription
        }
    }
    
    private func runImport() async {
        isImporting = true
        defer { isImporting = false }
        do {
            let result = try await container.statementImportService.importRows(previewRows)
            appState.showToast(
                title: "Import Complete",
                message: "\(result.importedCount) imported, \(result.skippedDuplicates) duplicates skipped",
                type: .success
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
