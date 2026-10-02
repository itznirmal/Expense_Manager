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
    @Environment(AppState.self) private var appState
    @Environment(DependencyContainer.self) private var container

    @State private var showFilePicker = false
    @State private var previewRows: [StatementImportRow] = []
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var accountHint: String = ""
    @State private var importCurrencyCode: String = CurrencyFormatter.defaultCurrencyCode

    private var availableImportCurrencies: [String] {
        var codes = CurrencyFormatter.supportedCurrencyCodes
        if !codes.contains(importCurrencyCode) {
            codes.insert(importCurrencyCode, at: 0)
        }
        return codes
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Import supported comma-separated bank statements when Shortcuts SMS misses history. Date, amount, merchant/narration, debit/credit, and optional ISO currency columns are detected; invalid rows stop the preview.")
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textSecondary)

                    Picker("Import Currency", selection: $importCurrencyCode) {
                        ForEach(availableImportCurrencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }

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
                                    Text(CurrencyFormatter.shared.format(amount: row.amount, currencyCode: row.currencyCode))
                                        .foregroundStyle(row.type == .income ? ColorTokens.incomeAccent : ColorTokens.expenseAccent)
                                }
                                Text("\(row.currencyCode) · \(row.date.formatted(date: .abbreviated, time: .omitted))")
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
                allowedContentTypes: [.commaSeparatedText, .plainText],
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
                defaultAccountHint: accountHint.isEmpty ? nil : accountHint,
                currencyCode: importCurrencyCode
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
            let failedText = result.failedCount == 0 ? "" : ", \(result.failedCount) failed"
            appState.showToast(
                title: "Import Complete",
                message: "\(result.importedCount) imported, \(result.skippedDuplicates) duplicates skipped\(failedText)",
                type: .success
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
