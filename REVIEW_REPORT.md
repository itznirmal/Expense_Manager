# Expense Manager — Comprehensive Review Report

**Review date:** 2026-08-26  
**Review mode:** Read-only whole-repository audit  
**Final verdict:** **BLOCKING DEFECTS FOUND**

## Executive Summary

The repository is not production-ready and is not currently buildable as delivered. It contains substantial SwiftUI, SwiftData, parsing, financial, export, and test source code, but it has no Xcode project, Swift package manifest, target configuration, Info.plist, entitlements, or stored build/test evidence. Multiple production and test files also reference incompatible generations of the app's own APIs, which creates confirmed compile-time failures.

The audit examined 120 Swift files, approximately 19,000 source lines, 14 test files, and 126 declared test methods. Three independent review lenses covered architecture, feature/spec completeness, and adversarial corner cases. No application files were modified during the review.

## Verification Scope and Limitations

- Available: filesystem inspection, static source analysis, architecture/spec comparison, SwiftData schema review, test-source inspection.
- Unavailable: macOS, Xcode, Swift compiler, iOS Simulator, signing, App Intents runtime, speech runtime, and device biometric testing.
- The folder is not a Git repository, so commit history and claimed fix commits could not be verified.
- No `evidence/` directory or stored compiler, test, simulator, screenshot, or runtime output exists.
- Static compile blockers below are confirmed by comparing call sites with the declarations present in this repository. Runtime-only behavior remains unverified until the project builds on macOS/Xcode.

---

## 1. Standards and Architecture Compliance

### P0 — No buildable iOS project or package

There is no `.xcodeproj`, `.xcworkspace`, `Package.swift`, Info.plist, entitlements file, asset catalog, or configured application/test target. `README.md:203-216` nevertheless instructs users to open `ExpenseManager.xcodeproj` or the folder as a Swift package.

**Impact:** Source inclusion, deployment targets, privacy usage descriptions, App Intents, capabilities, signing, and the advertised test suite cannot be built or verified.

### P0 — Production source targets incompatible internal APIs

Confirmed examples include:

- `ExpenseManager/Core/AppIntents/LogExpenseIntent.swift:65-138` references nonexistent `DatabaseContainer.modelContainer`, `AccountRecord.isDefault`, old `TransactionRecord` initializer labels, `TransactionStatus`, `AccountRecord.updatedAt`, and `accountNumberMask`.
- `ExpenseManager/Core/AppIntents/ParseTextExpenseIntent.swift:36` references nonexistent `DatabaseContainer.shared.modelContainer`; the current property is `container`.
- `ExpenseManager/Core/SMSParsing/BankSMSParser.swift:86` accesses nonexistent `ExtractedAccountHint.accountLastFour`; the current property is `lastFour`.
- `ExpenseManager/Core/SMSParsing/SMSIngestionOrchestrator.swift:143-170` calls a nonexistent labeled `createTransaction` overload and then accesses `.id` on the returned `String`.
- `ExpenseManager/Features/VoiceEntry/VoiceEntryViewModel.swift:65-70,218-244` uses outdated account/category fetch signatures, a nonexistent transaction overload, `AppLogger.error`, and nonexistent `learnRule`.
- `ExpenseManager/Features/SMSDiagnostics/SMSDiagnosticsViewModel.swift:34,210` uses undefined `ConfidenceTier` and `rawScore`.
- `ExpenseManager/Features/VoiceEntry/VoiceEntryView.swift:270` and `Features/Transactions/TransactionDetailView.swift:219` use undefined confidence properties.
- `ExpenseManager/Features/Accounts/AccountsListViewModel.swift:33` references absent `AccountType.savings` and `.investment` cases.
- `ExpenseManager/Core/Storage/DatabaseContainer.swift:34` and `Features/Transactions/TransactionsListViewModel.swift:258,287` reference logger members that `AppLogger` does not define.
- `ExpenseManager/Features/ReviewQueue/ReviewQueueViewModel.swift:167` uses absent `InputSource.ocr`.

**Impact:** The app target cannot compile even if a project manifest is added.

### P0 — Test sources also target removed APIs

`ExpenseManager/Tests/ExportTests/DataExportAndSecurityTests.swift:109,126,197,364` calls nonexistent `saveTransaction`, and line 200 calls nonexistent `saveBudget`. The current protocols expose `createTransaction(_:)` and `setBudget(...)`. Other tests reference absent `.ocr` symbols.

**Impact:** The claimed 126 tests are not executable evidence and cannot currently compile.

### P1 — App Intent bypasses the unified transaction pipeline

`LogExpenseIntent.swift:65-138` directly fetches and inserts SwiftData objects, mutates account balances, and creates fingerprints rather than producing a `TransactionCandidate` and calling the canonical domain service.

**Impact:** Siri behavior can diverge from manual, smart-text, voice, and SMS validation, accounting, duplicate prevention, and error handling.

### P1 — Ledger mutations are not rollback-safe

`SwiftDataTransactionService.swift:107-111` changes balances before saving the transaction. Updates roll back and reapply balances before `modelContext.save()` at lines 123-151. Failures do not restore the previous context state.

**Impact:** A constraint, disk, or persistence error can leave account balances inconsistent with stored transactions.

### P1 — Restore and purge are destructive and non-atomic

`DataExportService.swift:243-255` deletes the current database before inserting restored records. A later failure is only wrapped and rethrown at lines 358-370. Purge follows a similar delete-then-save flow.

**Impact:** A structurally valid backup that fails during insertion or save can leave the database empty or partially restored.

### P2 — Main-actor full-store processing will not scale

`SwiftDataTransactionService.swift:52-77,166-185` fetches entire stores and filters/aggregates them in memory on the main actor. Dashboard and analytics repeat full-history computations.

**Impact:** Large ledgers can produce slow launches, scrolling delays, and UI stalls.

### P2 — No explicit SwiftData migration plan

`DatabaseContainer.swift:15-25,54-62` defines only one static schema and configuration, with no `VersionedSchema` or migration stages.

**Impact:** Future schema changes can make existing user stores fail to open without a controlled migration path.

---

## 2. Functional Specification and Feature Audit

### P1 — Transaction editing creates instead of updating

`ManualTransactionComposerViewModel.swift:39,68-82` retains the editing transaction ID, but lines 173-193 always invoke `createTransaction`. Edit routes from the transaction list, dashboard, detail screen, review queue, and Smart Entry all reach this composer.

**Impact:** Editing can fail on the unique ID constraint or create a second transaction and apply its balance effect twice.

### P1 — Account balance edits are silently ignored

`AccountComposerView.swift:188-199` sets `updated.balance`, but `SwiftDataAccountService.updateAccount()` at lines 87-100 updates metadata only and never assigns `currentBalance` or `openingBalance`.

**Impact:** The UI reports success while the stored balance remains unchanged.

### P1 — Automatic account suggestions often do not resolve

`AccountHintParser.swift:139-148` emits strings such as `HDFC Bank •••• 8432`. `SwiftDataTransactionService.swift:241-247` resolves accounts only by exact ID or exact name.

**Impact:** A high-confidence import can display an account suggestion yet persist with `account == nil`, leaving account balances and net worth unchanged.

### P1 — Review Queue is not durable or connected end-to-end

`SMSIngestionOrchestrator.swift:171-173` merely returns `.reviewRequired`; it does not persist a queue item. `ParseTextExpenseIntent.swift:58-60` nevertheless tells the user that the item was added to Review Queue. `ReviewQueueViewModel.swift:55-69` fetches already-persisted transactions or injects hard-coded sample records into the production UI.

Accepting a persisted review item calls `createTransaction` again at `ReviewQueueViewModel.swift:80-86`, and the accepted state is not represented persistently.

**Impact:** Ambiguous SMS candidates disappear after the intent completes or the app restarts, while existing low-confidence transactions may reappear or be duplicated.

### P1 — Delete failures are reported as success

`TransactionDetailView.swift:81-87` uses `try?` when deleting and then always shows a successful deletion toast, removes the row through its callback, and dismisses the sheet.

**Impact:** Failed deletions disappear from the current screen and reappear later without an honest error message.

### P2 — Category management is incomplete

`CategoryServiceProtocol.swift:20-31` exposes creation, fetch, and seeding only. `CategoriesManagementView.swift:84-125` has no category edit or delete actions.

**Impact:** Users cannot correct or remove custom categories or manage relationship behavior for categories already used by transactions.

### P2 — Budget capabilities are narrower than the specification

`BudgetRecord.swift:14-21` and `BudgetComposerView.swift:37-54` implement monthly budgets only. Weekly, yearly, and custom cadence support is absent. The stored alert threshold is also not the actual rule used by `BudgetsViewModel.atRiskBudgets`, which instead compares progress against elapsed-month pace plus 15%.

**Impact:** The UI promises configurable warning thresholds that do not control the warning calculation.

### P2 — The claimed three-layer parser has no Foundation Model layer

`ParserOrchestrator.swift:35-70` contains deterministic parsing, merchant-rule lookup, and confidence scoring, but no Foundation Models integration.

**Impact:** Documentation and architecture claims overstate ambiguity handling.

### P2 — Siri and Shortcuts coverage is incomplete

`ExpenseShortcutsProvider.swift:15-38` registers only Log Expense and Parse Text/SMS. Planned Open Transaction Entry and Check Spending actions are absent. The SMS setup guide also tells users to search for action names that do not match the registered titles.

### P2 — Settings switches are not durable or functional

Default currency, biometric requirement, and SMS automation are plain in-memory properties. They are not backed by `@AppStorage`/secure storage and are not consumed by the runtime behaviors they describe.

### Planned or claimed features not implemented

- Receipt OCR and payment screenshot import
- Bulk text import
- Widgets
- Notifications and granular notification controls
- Merchant-rule editor in Settings
- Biometric lock screen

Receipt/screenshot features are identified as later-scope work in parts of the master plan, but `QUALITY_BAR.md` and `ARCHITECTURE.md` still describe OCR as part of the unified pipeline. Release scope and documentation need one authoritative definition.

---

## 3. Adversarial Invariants, Security, and Edge Cases

### P1 — Raw bank SMS is persisted and exported

`SMSIngestionOrchestrator.swift:58-71` copies `smsText` into the parsed draft. Lines 185-202 copy the raw text into `TransactionCandidate.notes`; `SwiftDataTransactionService.swift:87-111` persists it. `DataExportService.swift:80-82,151` includes notes in CSV and JSON backups.

**Impact:** Full bank messages can remain in SwiftData and user exports, directly violating `QUALITY_BAR.md`'s no-raw-SMS requirement.

### P1 — Biometric protection is a no-op

The only implementation is `SettingsViewModel.requireBiometrics` and the toggle in `SettingsView.swift:41-43`. `AppState.isBiometricallyLocked` is unused. There is no `LocalAuthentication`, `LAContext`, root gating, cancellation/lockout handling, or fail-closed state.

**Impact:** Enabling Face ID / Passcode does not protect any financial data.

### P1 — Voice processing is not guaranteed to stay on-device

`AudioRecordingService.swift:130-133` creates an `SFSpeechAudioBufferRecognitionRequest` without setting `requiresOnDeviceRecognition`. `PrivacyGuaranteeView.swift:68-70` promises that audio is never sent off the phone.

**Impact:** The privacy promise is stronger than the implementation guarantees.

### P1 — Voice recording lifecycle is not closed on dismissal

`VoiceEntryView.swift:70-72` dismisses the sheet without stopping recording. Its `.task` auto-starts recording at lines 88-100, while `VoiceEntryViewModel.startListening()` creates a background task without a dismissal cancellation path.

**Impact:** Microphone and speech-recognition work can continue after the modal closes.

### P1 — Incoming credits containing transfer terms are misclassified

`TransactionDirectionClassifier.swift:77-86` checks transfer keywords before income keywords. Bank messages such as “credited ... by NEFT” or “salary transfer” therefore match `.transfer` before `.income`.

**Impact:** A genuine credit can debit an account and be excluded from income totals.

### P1 — Transfers and cash withdrawals permit one-sided accounting

`SwiftDataTransactionService.swift:190-208` requires only a source account and makes destination credit optional. Manual validation checks amount and merchant/category but does not require two distinct accounts. Parser code synthesizes the name `Savings Account` instead of requiring a resolved destination.

**Impact:** Missing or unresolved destinations debit the source and credit nobody. ATM withdrawals receive no cash destination, reducing net worth even though the withdrawn cash still exists.

### P1 — Duplicate prevention is raceable and can silently fail

`SMSIngestionOrchestrator.swift:91-109` checks fingerprints, saves the transaction at lines 142-157, and records the fingerprint afterward at lines 159-168. `sourceHash` is not unique, and fingerprint-save errors are swallowed with `try?`.

**Impact:** Concurrent imports can both pass the check, and a fingerprint failure allows the same message to be imported again.

### P1 — Backup/restore discards duplicate history

`BackupData` contains accounts, categories, tags, transactions, budgets, and merchant rules, but no import fingerprints. Restore deletes all fingerprints and never recreates them.

**Impact:** Previously imported bank messages can be imported again after a restore.

### P1 — Common bank SMS dates are ignored

`DateParser.swift:112-196` does not recognize formats used by the repository's own bank fixtures, including `25-AUG-26`, `25-Aug-26`, and `25Aug26`. `BankSMSParser.swift:98-100` silently falls back to the ingestion time.

**Impact:** Month totals, sorting, analytics, and dedupe windows use the wrong transaction date.

### P1 — App Intent monetary handling and save reporting are unsafe

`LogExpenseIntent.swift:20-21` accepts `Double`, then rounds to two decimals at lines 62-64. It suppresses context-save errors at line 138 and still returns a “Logged” confirmation.

**Impact:** Fractional-minor-unit currencies and very large amounts can lose precision, and failed saves are reported as successful.

### P1 — Cross-currency net worth is mathematically invalid

Accounts store a currency code, but `SwiftDataAccountService.calculateNetWorth()` at lines 112-120 and dashboard/account summaries directly sum every balance without conversion or currency grouping.

**Impact:** INR, USD, EUR, and other balances are added as though they were the same unit.

### P2 — CSV sanitizer has bypass-risk boundaries

`CSVFormulaSanitizer.neutralize()` checks only the first character. A field containing leading whitespace or control characters before a formula trigger is quoted but not neutralized with a leading apostrophe.

**Impact:** Protection is correct for the six directly tested prefixes but incomplete for adversarially padded values.

### P2 — Accessibility and Dynamic Type requirements are not met

The UI contains no explicit accessibility labels, hints, values, or traits. Financial amount fonts in `Typography.swift:18-27` use fixed sizes without scaling relative to a text style, and several custom controls have visual targets below 44 points.

**Impact:** VoiceOver users may encounter ambiguous controls, and large Dynamic Type sizes can clip or remain unscaled.

### P2 — Error states are frequently hidden

Several view models populate `errorMessage`, but their parent views do not render it. A failed load can therefore look like a legitimate empty database.

---

## Feature Status Matrix

| Area | Status | Principal finding |
|---|---|---|
| Repository/build | Blocked | No project/manifest; extensive compile drift |
| Architecture | Failed | Multiple incompatible API generations and pipeline bypasses |
| Financial ledger | Failed | One-sided transfers, edit duplication, non-atomic saves |
| Manual entry | Partial | Creation design exists; edit and transfer validation fail |
| Smart text | Partial | Deterministic parser exists; account resolution is unsafe |
| Voice entry | Broken | Compile drift, lifecycle leakage, privacy overclaim |
| Siri/App Intents | Broken | Compile drift, direct persistence, imprecise amount and false success |
| SMS ingestion | Broken | Compile drift, wrong dates/directions, raw-text retention, dedupe race |
| Review Queue | Broken | Not durable; misleading success; sample records in production UI |
| Transactions | Partial | Search/filter UI exists; edit/delete error paths fail |
| Accounts | Partial | Create/archive exist; balance edit and multi-currency totals fail |
| Categories | Partial | Create only; no edit/delete |
| Budgets | Partial | Monthly only; configured threshold not honored |
| Analytics | Partial | Useful calculations, but main-actor full-store processing |
| Export | Partial | Direct formula triggers sanitized; raw SMS and padded formulas remain risks |
| Backup/restore | Unsafe | Non-atomic and drops fingerprint history |
| Biometrics/security | Failed | No implemented app lock |
| Accessibility/HIG | Failed | Missing accessibility metadata and scalable custom typography |
| Automated tests | Blocked | Test source exists but target/APIs are not buildable |
| Documentation/evidence | Failed | Production claims are unsupported by executable evidence |

## Confirmed Strengths

- Persistent monetary fields use `Decimal` in the primary account, transaction, and budget models.
- Transfer effects are intentionally excluded from income/expense totals when both accounts are valid.
- SwiftData includes an in-memory container factory for tests and previews.
- SMS safety classification covers OTP, failed/declined payments, marketing, bill reminders, card-blocked messages, and balance-only alerts.
- CSV formula neutralization handles the six directly required trigger characters and is applied to exported text fields.
- Most feature view models use `@Observable` and `@MainActor`.
- Semantic system background and text colors support light and dark appearance.
- The repository contains substantial unit-test intent, including financial, parser, SMS, duplicate, export, dashboard, budget, and analytics cases.

These strengths cannot be treated as verified passes until the app and tests compile and run.

## Evidence Integrity Assessment

`CHECKPOINT.md` states that production verification is complete, but the repository contains:

- no Git metadata or verifiable fix commits;
- no buildable Xcode project or Swift package;
- no `evidence/` directory;
- no stored compiler or test output;
- no simulator/device screenshots or runtime observations;
- issue-ledger “fix commits” that are prose descriptions rather than commit identifiers.

The existing checkpoint should therefore be treated as an implementation narrative, not a verified release record.

## Recommended Recovery Sequence

1. Create or restore the real Xcode project, application target, test target, Info.plist privacy keys, entitlements, assets, and signing configuration.
2. Reconcile all production and test callers against one canonical set of models, enums, and service protocols until a clean build succeeds.
3. Make biometric lock, raw-SMS handling, voice privacy, export sanitization, and restore safety release-blocking work.
4. Enforce financial invariants at the service boundary: valid positive amount, resolved source, distinct required destination, currency rules, and atomic mutation.
5. Repair create-versus-update behavior for transaction and account editing.
6. Implement a durable review queue and transactional duplicate prevention.
7. Add regression tests for every P0/P1 trigger before fixing it, then run the full suite in Xcode.
8. Complete accessibility, error-state, performance, and missing-feature work only after correctness and privacy blockers are closed.
9. Run the Gauntlet `BUILD -> RUN -> OBSERVE -> CRITIQUE -> FIX -> VERIFY` loop on macOS/Xcode and store real evidence artifacts.
10. Update README, architecture, checkpoint, and issue-ledger claims only after the corresponding evidence exists.

## Final Release Verdict

**BLOCKING DEFECTS FOUND**

The repository must not be described as production-ready or submitted for App Store packaging in its current state. The first milestone is a compilable application and test target; the second is closure of privacy and financial-integrity defects; runtime UI polish and shipping verification come afterward.
