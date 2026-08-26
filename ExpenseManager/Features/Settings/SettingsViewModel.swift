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
import LocalAuthentication

/// ViewModel managing application settings, CSV export, JSON backup/restore, biometrics, and database purging.
@Observable
@MainActor
public final class SettingsViewModel {
    
    // MARK: - State Properties
    
    public var defaultCurrency: String = "INR"
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
    
    // MARK: - Biometric Toggle Check (GT-66)
    
    public func toggleBiometrics(enable: Bool, appState: AppState) {
        let context = LAContext()
        var authError: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            appState.requireBiometrics = false
            appState.showToast(
                title: "Authentication Unavailable",
                message: authError?.localizedDescription ?? "Face ID or Passcode is not configured on this device.",
                type: .warning
            )
            return
        }
        
        let reason = enable ? "Authenticate to enable App Lock." : "Authenticate to disable App Lock."
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            Task { @MainActor in
                if success {
                    appState.requireBiometrics = enable
                    appState.showToast(
                        title: "Security Updated",
                        message: enable ? "App Lock enabled." : "App Lock disabled.",
                        type: .success
                    )
                } else {
                    // Revert UI if needed, but since it's an intent, we just don't change the state.
                    appState.showToast(
                        title: "Authentication Failed",
                        message: "Unable to change security settings.",
                        type: .error
                    )
                }
            }
        }
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
            let csvData = Data(csvContent.utf8)
            try csvData.write(to: fileURL, options: .completeFileProtection)
            
            cleanupTempFiles(excluding: fileURL)
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
            try backupData.write(to: fileURL, options: .completeFileProtection)
            
            cleanupTempFiles(excluding: fileURL)
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
    
    private func cleanupTempFiles(excluding url: URL) {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else { return }
        
        for file in files {
            if file.lastPathComponent.hasPrefix("ExpenseManager_") && file != url {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
