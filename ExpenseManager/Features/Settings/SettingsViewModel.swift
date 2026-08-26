//
//  SettingsViewModel.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Settings, Data Export, Backup & Privacy ViewModel.
//

import SwiftUI
import Observation
import UniformTypeIdentifiers

/// ViewModel managing application settings, CSV export, JSON backup/restore, biometrics, and database purging.
@Observable
@MainActor
public final class SettingsViewModel {
    
    // MARK: - State Properties
    
    public var defaultCurrency: String = "INR"
    public var requireBiometrics: Bool = false
    public var autoParseSMS: Bool = true
    
    public var isExportingCSV: Bool = false
    public var csvExportURL: URL? = nil
    
    public var isExportingBackup: Bool = false
    public var backupExportURL: URL? = nil
    
    public var showRestoreFilePicker: Bool = false
    public var showRestoreConfirmationAlert: Bool = false
    public var pendingRestorePayload: BackupPayload? = nil
    public var selectedRestoreData: Data? = nil
    
    public var showPurgeConfirmationAlert: Bool = false
    public var isPurgingData: Bool = false
    
    public var showSMSGuideSheet: Bool = false
    public var showPrivacyInfoSheet: Bool = false
    
    // MARK: - Services
    
    private let exportService: DataExportServiceProtocol
    
    // MARK: - Initializer
    
    public init(exportService: DataExportServiceProtocol = MockDataExportService()) {
        self.exportService = exportService
    }
    
    // MARK: - CSV Export (AC-SEC-1 Protected)
    
    public func exportCSV(appState: AppState) async {
        isExportingCSV = true
        defer { isExportingCSV = false }
        
        do {
            let csvContent = try await exportService.exportTransactionsToCSV(startDate: nil, endDate: nil)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let filename = "ExpenseManager_Ledger_\(timestamp).csv"
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            
            self.csvExportURL = fileURL
            appState.showToast(
                title: "CSV Export Ready",
                message: "Formula injection neutralized (AC-SEC-1). Tap Share to save.",
                type: .success
            )
        } catch {
            appState.showToast(
                title: "Export Failed",
                message: error.localizedDescription,
                type: .error
            )
        }
    }
    
    // MARK: - JSON Backup Export
    
    public func exportJSONBackup(appState: AppState) async {
        isExportingBackup = true
        defer { isExportingBackup = false }
        
        do {
            let backupData = try await exportService.exportJSONBackup()
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let filename = "ExpenseManager_Backup_\(timestamp).json"
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(filename)
            try backupData.write(to: fileURL)
            
            self.backupExportURL = fileURL
            appState.showToast(
                title: "Backup Created",
                message: "Full database packaged with SHA-256 integrity checksum.",
                type: .success
            )
        } catch {
            appState.showToast(
                title: "Backup Failed",
                message: error.localizedDescription,
                type: .error
            )
        }
    }
    
    // MARK: - JSON Backup Restore
    
    public func handleSelectedBackupURL(_ result: Result<URL, Error>, appState: AppState) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                appState.showToast(title: "Permission Denied", message: "Cannot read the selected backup file.", type: .error)
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                let payload = try exportService.validateBackupPayload(data)
                
                self.selectedRestoreData = data
                self.pendingRestorePayload = payload
                self.showRestoreConfirmationAlert = true
            } catch {
                appState.showToast(title: "Invalid Backup", message: error.localizedDescription, type: .error)
            }
            
        case .failure(let error):
            appState.showToast(title: "File Selection Error", message: error.localizedDescription, type: .error)
        }
    }
    
    public func executeRestore(appState: AppState) async {
        guard let data = selectedRestoreData else { return }
        
        do {
            let result = try await exportService.restoreJSONBackup(from: data)
            self.selectedRestoreData = nil
            self.pendingRestorePayload = nil
            
            appState.showToast(
                title: "Restore Complete",
                message: "Restored \(result.transactionsRestored) txs, \(result.accountsRestored) accounts, and \(result.categoriesRestored) categories.",
                type: .success
            )
        } catch {
            appState.showToast(
                title: "Restore Failed",
                message: error.localizedDescription,
                type: .error
            )
        }
    }
    
    // MARK: - Data Purge / Factory Reset
    
    public func executePurge(appState: AppState) async {
        isPurgingData = true
        defer { isPurgingData = false }
        
        do {
            try await exportService.purgeAllData(restoreDefaultCategories: true)
            appState.showToast(
                title: "Database Reset",
                message: "All user records wiped. Default categories restored.",
                type: .info
            )
        } catch {
            appState.showToast(
                title: "Reset Failed",
                message: error.localizedDescription,
                type: .error
            )
        }
    }
}
