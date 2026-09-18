//
//  StatementCSVImportService.swift
//  ExpenseManager
//
//  Flexible bank CSV / statement import with duplicate fingerprints.
//

import Foundation

/// Parsed row from a user-provided bank statement CSV.
public struct StatementImportRow: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var date: Date
    public var amount: Decimal
    public var merchant: String
    public var type: TransactionType
    public var notes: String?
    public var accountHint: String?
    
    public init(
        id: UUID = UUID(),
        date: Date,
        amount: Decimal,
        merchant: String,
        type: TransactionType,
        notes: String? = nil,
        accountHint: String? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.merchant = merchant
        self.type = type
        self.notes = notes
        self.accountHint = accountHint
    }
}

public struct StatementImportResult: Sendable, Equatable {
    public let importedCount: Int
    public let skippedDuplicates: Int
    public let failedCount: Int
    public let warnings: [String]
    
    public init(importedCount: Int, skippedDuplicates: Int, failedCount: Int, warnings: [String]) {
        self.importedCount = importedCount
        self.skippedDuplicates = skippedDuplicates
        self.failedCount = failedCount
        self.warnings = warnings
    }
}

public protocol StatementCSVImportServiceProtocol: Sendable {
    func parseCSV(_ csvText: String, defaultAccountHint: String?) throws -> [StatementImportRow]
    func importRows(_ rows: [StatementImportRow]) async throws -> StatementImportResult
}

public enum StatementCSVImportError: LocalizedError, Sendable {
    case emptyFile
    case missingRequiredColumns
    case noValidRows
    
    public var errorDescription: String? {
        switch self {
        case .emptyFile: return "The CSV file is empty."
        case .missingRequiredColumns: return "CSV must include Date and Amount columns (Merchant optional)."
        case .noValidRows: return "No valid transaction rows were found in the CSV."
        }
    }
}

/// Heuristic CSV importer supporting common bank export headers.
public final class StatementCSVImportService: StatementCSVImportServiceProtocol, Sendable {
    private let transactionService: TransactionServiceProtocol
    private let fingerprintService: ImportFingerprintServiceProtocol?
    
    public init(
        transactionService: TransactionServiceProtocol,
        fingerprintService: ImportFingerprintServiceProtocol? = nil
    ) {
        self.transactionService = transactionService
        self.fingerprintService = fingerprintService
    }
    
    public func parseCSV(_ csvText: String, defaultAccountHint: String? = nil) throws -> [StatementImportRow] {
        let lines = csvText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        
        guard let headerLine = lines.first else { throw StatementCSVImportError.emptyFile }
        let headers = Self.parseCSVLine(headerLine).map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        
        guard let dateIndex = Self.index(of: ["date", "txn date", "transaction date", "value date", "posted"], in: headers),
              let amountIndex = Self.index(of: ["amount", "txn amount", "transaction amount", "debit", "withdrawal"], in: headers)
                ?? Self.creditDebitPair(in: headers)?.debit
        else {
            throw StatementCSVImportError.missingRequiredColumns
        }
        
        let creditIndex = Self.index(of: ["credit", "deposit", "cr"], in: headers)
            ?? Self.creditDebitPair(in: headers)?.credit
        let merchantIndex = Self.index(of: ["merchant", "description", "narration", "particulars", "payee", "details"], in: headers)
        let typeIndex = Self.index(of: ["type", "transaction type", "dr/cr", "credit/debit"], in: headers)
        let notesIndex = Self.index(of: ["notes", "memo", "reference", "ref"], in: headers)
        
        var rows: [StatementImportRow] = []
        for line in lines.dropFirst() {
            let cols = Self.parseCSVLine(line)
            guard cols.count > max(dateIndex, amountIndex) else { continue }
            
            guard let date = Self.parseDate(cols[dateIndex]) else { continue }
            
            var amount: Decimal = .zero
            var type: TransactionType = .expense
            
            if let creditIndex, cols.indices.contains(creditIndex),
               let credit = Self.parseAmount(cols[creditIndex]), credit > 0 {
                amount = credit
                type = .income
            } else if let parsed = Self.parseAmount(cols[amountIndex]) {
                amount = abs(parsed)
                if parsed < 0 {
                    type = .expense
                } else if let typeIndex, cols.indices.contains(typeIndex) {
                    type = Self.inferType(from: cols[typeIndex], amount: parsed)
                } else if creditIndex != nil {
                    // Debit column style
                    type = .expense
                } else {
                    type = parsed >= 0 ? .expense : .income
                }
            } else {
                continue
            }
            
            guard amount > 0 else { continue }
            
            let merchant: String = {
                if let merchantIndex, cols.indices.contains(merchantIndex) {
                    let value = cols[merchantIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty { return value }
                }
                return "Imported Transaction"
            }()
            
            let notes: String? = {
                if let notesIndex, cols.indices.contains(notesIndex) {
                    let value = cols[notesIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? nil : value
                }
                return nil
            }()
            
            rows.append(StatementImportRow(
                date: date,
                amount: amount,
                merchant: merchant,
                type: type,
                notes: notes,
                accountHint: defaultAccountHint
            ))
        }
        
        guard !rows.isEmpty else { throw StatementCSVImportError.noValidRows }
        return rows
    }
    
    public func importRows(_ rows: [StatementImportRow]) async throws -> StatementImportResult {
        var imported = 0
        var skipped = 0
        var failed = 0
        var warnings: [String] = []
        
        for row in rows {
            let hash = ImportFingerprintService.computeSourceHash(
                amount: row.amount,
                merchant: row.merchant,
                timestamp: row.date,
                reference: row.notes
            )
            
            if let fingerprintService,
               (try? await fingerprintService.hasFingerprint(hash: hash)) == true {
                skipped += 1
                continue
            }
            
            let candidate = TransactionCandidate(
                type: row.type,
                amount: row.amount,
                merchantName: row.merchant,
                accountSuggestion: row.accountHint,
                transactionDate: row.date,
                notes: row.notes,
                source: .bulkImport,
                sourceReference: hash,
                confidence: .high,
                needsReview: false
            )
            
            do {
                _ = try await transactionService.createTransaction(candidate)
                try? await fingerprintService?.recordFingerprint(
                    sourceHash: hash,
                    amount: row.amount,
                    merchant: row.merchant,
                    accountLastFour: nil,
                    reference: row.notes,
                    timestamp: row.date,
                    source: "csv"
                )
                imported += 1
            } catch {
                failed += 1
                warnings.append("Failed \(row.merchant): \(error.localizedDescription)")
            }
        }
        
        return StatementImportResult(
            importedCount: imported,
            skippedDuplicates: skipped,
            failedCount: failed,
            warnings: warnings
        )
    }
    
    // MARK: - Helpers
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    private static func index(of aliases: [String], in headers: [String]) -> Int? {
        for (idx, header) in headers.enumerated() {
            if aliases.contains(where: { header == $0 || header.contains($0) }) {
                return idx
            }
        }
        return nil
    }
    
    private static func creditDebitPair(in headers: [String]) -> (debit: Int, credit: Int)? {
        guard let debit = index(of: ["debit", "withdrawal", "dr"], in: headers),
              let credit = index(of: ["credit", "deposit", "cr"], in: headers) else {
            return nil
        }
        return (debit, credit)
    }
    
    private static func parseAmount(_ raw: String) -> Decimal? {
        var cleaned = raw
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("(") && cleaned.hasSuffix(")") {
            cleaned = "-" + cleaned.dropFirst().dropLast()
        }
        return Decimal(string: cleaned)
    }
    
    private static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = [
            "yyyy-MM-dd", "dd-MM-yyyy", "dd/MM/yyyy", "MM/dd/yyyy",
            "dd-MMM-yyyy", "dd MMM yyyy", "yyyy/MM/dd", "dd-MM-yy"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }
    
    private static func inferType(from raw: String, amount: Decimal) -> TransactionType {
        let lower = raw.lowercased()
        if lower.contains("credit") || lower == "cr" || lower.contains("income") || lower.contains("deposit") {
            return .income
        }
        if lower.contains("transfer") {
            return .transfer
        }
        if amount < 0 { return .income }
        return .expense
    }
}
