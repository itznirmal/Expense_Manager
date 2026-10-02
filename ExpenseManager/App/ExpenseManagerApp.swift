import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

@main
@MainActor
struct ExpenseManagerApp: App {
    @State private var appState = AppState()
    @State private var database: DatabaseContainer?
    @State private var services: DependencyContainer?
    @State private var startupError: String?
    @State private var isOpeningStore = false
    @State private var showRecoveryPicker = false
    @State private var showRecoveryConfirmation = false
    @State private var recoveryData: Data?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let database, let services {
                    RootView()
                        .environment(services)
                        .modelContainer(database.container)
                } else if let startupError {
                    ContentUnavailableView {
                        Label("Your records couldn't be opened", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(startupError + "\nYour existing files have been preserved. Retry after unlocking the device. If the problem persists, use the Mac recovery steps before restoring a backup.")
                    } actions: {
                        Button("Retry") { Task { await openStore() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(isOpeningStore)
                        Button("Restore a backup") { showRecoveryPicker = true }
                            .disabled(isOpeningStore)
                    }
                } else {
                    ProgressView("Opening your records…")
                }
            }
            .overlay {
                if database == nil && appState.shouldHideSensitiveContent {
                    if appState.isSceneActive { BiometricLockShieldView() }
                    else { ColorTokens.backgroundPrimary.ignoresSafeArea() }
                }
            }
            .environment(appState)
            .task { await openStore() }
            .fileImporter(isPresented: $showRecoveryPicker, allowedContentTypes: [.json]) { result in
                selectRecoveryBackup(result)
            }
            .confirmationDialog("Restore this backup into a new store?", isPresented: $showRecoveryConfirmation, titleVisibility: .visible) {
                Button("Restore backup") { Task { await restoreStartupBackup() } }
                Button("Cancel", role: .cancel) { recoveryData = nil }
            } message: {
                Text("The backup becomes your visible ledger. The original store files are preserved separately for investigation. Back up the app container before recovery if possible.")
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .background {
                    appState.lockApp()
                    showRecoveryPicker = false
                    showRecoveryConfirmation = false
                    recoveryData = nil
                }
                else if phase == .inactive { appState.coverSensitiveContent(dismissSheets: false) }
                else { appState.activateScene() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
                appState.lockApp()
                services = nil
                database = nil
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
                if scenePhase == .active { appState.activateScene() }
                Task { await openStore() }
            }
        }
    }

    private func openStore() async {
        guard database == nil, !isOpeningStore else { return }
        isOpeningStore = true
        defer { isOpeningStore = false }
        guard UIApplication.shared.isProtectedDataAvailable else {
            startupError = "Unlock the device to access protected records."
            return
        }
        do {
            let store: ModelContainer
            let arguments = CommandLine.arguments
            if arguments.contains("-UITesting"),
               let index = arguments.firstIndex(of: "-UITestStore"), index + 1 < arguments.count {
                let testID = arguments[index + 1].filter { $0.isLetter || $0.isNumber || $0 == "-" }
                let testDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("UI-TestStores").appendingPathComponent(testID)
                store = try DatabaseContainer.createContainer(storeURL: testDirectory.appendingPathComponent("default.store"))
            } else if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                store = try DatabaseContainer.createContainer(inMemory: true)
            } else {
                store = try DatabaseContainer.production().container
            }
            let container = DependencyContainer.live(modelContainer: store)
            try await container.categoryService.seedDefaultCategoriesIfNeeded()
            guard UIApplication.shared.isProtectedDataAvailable else {
                startupError = "Unlock the device to access protected records."
                return
            }
            database = DatabaseContainer(container: store)
            services = container
            startupError = nil
            await appState.refreshPendingReview(container: container)
            if arguments.contains("-DisableAnimations") { UIView.setAnimationsEnabled(false) }
        } catch {
            startupError = "The store could not be opened safely. No records were replaced."
        }
    }

    private func selectRecoveryBackup(_ result: Result<URL, Error>) {
        guard !appState.shouldHideSensitiveContent else { return }
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else {
                startupError = "The selected backup could not be accessed."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            _ = try DataExportService.validateBackupPayloadData(data)
            recoveryData = data
            showRecoveryConfirmation = true
        } catch {
            startupError = "The backup could not be validated. Your existing files have been preserved."
        }
    }

    private func restoreStartupBackup() async {
        guard let data = recoveryData, !appState.shouldHideSensitiveContent, !isOpeningStore else { return }
        recoveryData = nil
        isOpeningStore = true
        defer { isOpeningStore = false }
        do {
            let defaultURL = ModelConfiguration(schema: DatabaseContainer.schema, cloudKitDatabase: .none).url
            let restored = try await StartupRecoveryService.restoreBackup(data: data, directory: defaultURL.deletingLastPathComponent(), preferences: CurrencyFormatter.preferences)
            guard UIApplication.shared.isProtectedDataAvailable else { return }
            database = restored
            services = DependencyContainer.live(modelContainer: restored.container)
            startupError = nil
        } catch {
            startupError = "Backup recovery could not complete. Original files are still preserved. Unlock the device and try again."
        }
    }
}
