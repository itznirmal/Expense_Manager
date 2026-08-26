//
//  SettingsView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Application Settings, Data Export, Backup, Restore & Privacy View.
//

import SwiftUI
import UniformTypeIdentifiers

public struct SettingsView: View {
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var viewModel: SettingsViewModel?
    
    public init() {}
    
    private var activeViewModel: SettingsViewModel {
        if let existing = viewModel { return existing }
        let vm = SettingsViewModel(exportService: container.dataExportService)
        return vm
    }
    
    public var body: some View {
        NavigationStack {
            let vm = activeViewModel
            @Bindable var bindableVM = vm
            
            Form {
                // MARK: - 1. General Preferences
                Section("Preferences") {
                    HStack {
                        Label("Default Currency", systemImage: "indianrupeesign.circle")
                        Spacer()
                        Text("INR (₹)")
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    
                    Toggle(isOn: $bindableVM.requireBiometrics) {
                        Label("Face ID / Passcode", systemImage: "faceid")
                    }
                    
                    NavigationLink {
                        AccountsListView()
                    } label: {
                        Label("Manage Accounts", systemImage: "building.columns.fill")
                    }
                    
                    NavigationLink {
                        CategoriesManagementView()
                    } label: {
                        Label("Category Taxonomy", systemImage: "tag.fill")
                    }
                }
                
                // MARK: - 2. Automation & Ingestion
                Section("Automation & Ingestion") {
                    Toggle(isOn: $bindableVM.autoParseSMS) {
                        Label("Shortcuts SMS Ingestion", systemImage: "message.badge.filled.fill")
                    }
                    
                    Button {
                        appState.presentSheet(.smsDiagnostics)
                    } label: {
                        Label("SMS Diagnostics Sandbox", systemImage: "stethoscope")
                    }
                    
                    Button {
                        appState.presentSheet(.voiceEntry)
                    } label: {
                        Label("Voice Entry Assistant", systemImage: "mic.fill")
                    }
                    
                    Button {
                        vm.showSMSGuideSheet = true
                    } label: {
                        Label("How to Setup SMS Automation", systemImage: "questionmark.circle")
                    }
                }
                
                // MARK: - 3. Data Export & Backup
                Section("Data Export & Backup") {
                    // CSV Export
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            Task {
                                await vm.exportCSV(appState: appState)
                            }
                        } label: {
                            HStack {
                                Label("Export Ledger as CSV", systemImage: "square.and.arrow.up")
                                Spacer()
                                if vm.isExportingCSV {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        
                        if let csvURL = vm.csvExportURL {
                            ShareLink(item: csvURL) {
                                Label("Share / Save CSV Ledger", systemImage: "square.and.arrow.up.fill")
                                    .font(Typography.caption.weight(.semibold))
                                    .foregroundStyle(ColorTokens.brandPrimary)
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    // JSON Backup Export
                    VStack(alignment: .leading, spacing: 6) {
                        Button {
                            Task {
                                await vm.exportJSONBackup(appState: appState)
                            }
                        } label: {
                            HStack {
                                Label("Export Full JSON Backup", systemImage: "externaldrive.badge.plus")
                                Spacer()
                                if vm.isExportingBackup {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        
                        if let backupURL = vm.backupExportURL {
                            ShareLink(item: backupURL) {
                                Label("Share / Save Backup Package", systemImage: "externaldrive.fill")
                                    .font(Typography.caption.weight(.semibold))
                                    .foregroundStyle(ColorTokens.incomeAccent)
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    // JSON Backup Restore
                    Button {
                        vm.showRestoreFilePicker = true
                    } label: {
                        Label("Restore from JSON Backup", systemImage: "arrow.counterclockwise.circle")
                    }
                }
                
                // MARK: - 4. Privacy & Security Invariants
                Section("Privacy & Security") {
                    Button {
                        vm.showPrivacyInfoSheet = true
                    } label: {
                        HStack {
                            Label("Privacy Guarantee", systemImage: "lock.shield.fill")
                            Spacer()
                            HStack(spacing: 4) {
                                Text("100% On-Device")
                                    .font(Typography.caption.weight(.semibold))
                                    .foregroundStyle(ColorTokens.incomeAccent)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(ColorTokens.textSecondary)
                            }
                        }
                    }
                    .foregroundStyle(ColorTokens.textPrimary)
                    
                    HStack {
                        Label("CSV Sanitization", systemImage: "shield.checkered")
                        Spacer()
                        Text("AC-SEC-1 Formula Escaped")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                
                // MARK: - 5. Danger Zone
                Section("Danger Zone") {
                    Button(role: .destructive) {
                        vm.showPurgeConfirmationAlert = true
                    } label: {
                        HStack {
                            Label("Factory Reset / Purge Data", systemImage: "trash.fill")
                            Spacer()
                            if vm.isPurgingData {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                }
                
                // MARK: - 6. About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Phase 21 Release)")
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    
                    HStack {
                        Text("Persistence")
                        Spacer()
                        Text("SwiftData (Local SQLite)")
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    
                    HStack {
                        Text("Architecture")
                        Spacer()
                        Text("Offline Clean Architecture")
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if viewModel == nil {
                    viewModel = SettingsViewModel(exportService: container.dataExportService)
                }
            }
            // Sheets & Modals
            .sheet(isPresented: $bindableVM.showSMSGuideSheet) {
                SMSAutomationGuideView()
            }
            .sheet(isPresented: $bindableVM.showPrivacyInfoSheet) {
                PrivacyGuaranteeView()
            }
            // File Importer for JSON Backup Restore
            .fileImporter(
                isPresented: $bindableVM.showRestoreFilePicker,
                allowedContentTypes: [.json]
            ) { result in
                vm.handleSelectedBackupURL(result, appState: appState)
            }
            // Restore Confirmation Alert
            .alert(
                "Restore Database Backup?",
                isPresented: $bindableVM.showRestoreConfirmationAlert
            ) {
                Button("Cancel", role: .cancel) {
                    vm.selectedRestoreData = nil
                    vm.pendingRestorePayload = nil
                }
                Button("Restore Database", role: .destructive) {
                    Task {
                        await vm.executeRestore(appState: appState)
                    }
                }
            } message: {
                if let payload = vm.pendingRestorePayload {
                    Text("This backup contains \(payload.data.transactions.count) transactions, \(payload.data.accounts.count) accounts, and \(payload.data.categories.count) categories.\n\nRestoring will replace all current data. SHA-256 integrity checksum is verified.")
                } else {
                    Text("Restoring will replace all current data. This action cannot be undone.")
                }
            }
            // Purge Confirmation Alert
            .alert(
                "Purge All Data?",
                isPresented: $bindableVM.showPurgeConfirmationAlert
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Purge Everything", role: .destructive) {
                    Task {
                        await vm.executePurge(appState: appState)
                    }
                }
            } message: {
                Text("This will permanently delete all transactions, custom accounts, budgets, and merchant rules. Default system categories will be restored. This action cannot be undone.")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
