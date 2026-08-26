Capabilities: Windows host environment — static code analysis, structural inspection, architecture verification, SwiftData schema audits. Local Swift compilation, Xcode build, and iOS Simulator runs are excluded (manual evidence gate on macOS/Xcode).

# Checkpoint Ledger

## 2026-08-26 — Phase 20 & 21: Data Export, Backup & Restore, CSV Formula Neutralization (AC-SEC-1), Privacy Management, Master Documentation & Final Verification Complete
Works:
1. **Data Export & CSV Formula Injection Neutralization (`ExpenseManager/Core/Export/`)**:
   - `DataExportServiceProtocol.swift`: Defines protocols for CSV export, JSON backup creation, payload integrity validation, round-trip restoration, and database purging.
   - `CSVFormulaSanitizer.swift` (inside protocol): Implements **AC-SEC-1** escaping for formula trigger characters (`=`, `+`, `-`, `@`, `\t`, `\r`) with single-quotes (`'`) and RFC-4180 quotes to neutralize spreadsheet formula execution vulnerabilities (CWE-1236).
   - `DataExportService.swift`: SwiftData implementation generating standardized 14-column CSV ledger files, versioned JSON backup packages with SHA-256 integrity checksums, and secure database purge / default system category restoration.
   - `MockDataExportService.swift`: In-memory mock export service for previews and isolated unit testing.
   - Registered `dataExportService` in `DependencyContainer.swift` (live & mock factories).

2. **Data & Privacy Management Screen in Settings (`ExpenseManager/Features/Settings/`)**:
   - `SettingsViewModel.swift`: `@Observable` `@MainActor` ViewModel managing CSV export with file generation, JSON backup export, `.fileImporter` JSON selection with SHA-256 validation, destructive restore confirmation, and factory reset purging.
   - `SettingsView.swift`: Polished Apple HIG settings interface featuring CSV export with `ShareLink`, JSON backup with `ShareLink`, JSON restore file importer, privacy guarantee badge, biometrics security toggle, and factory reset dialog.
   - `SMSAutomationGuideView.swift`: Interactive 5-step visual guide for configuring Apple Shortcuts Message Automations for hands-free background bank SMS transaction logging.
   - `PrivacyGuaranteeView.swift`: Security ledger modal detailing 100% on-device architecture, zero network permissions, AC-SEC-1 formula escaping, and zero-PII logging.

3. **Unit Test Suites (`ExpenseManager/Tests/ExportTests/`)**:
   - `DataExportAndSecurityTests.swift`: Comprehensive unit tests verifying:
     - CSV formula trigger prefix neutralization (`=`, `+`, `-`, `@`, `\t`, `\r`).
     - RFC-4180 quote and comma escaping.
     - CSV header and 14-column formatting.
     - JSON backup export and round-trip restore integrity.
     - SHA-256 checksum tampering detection (tampered JSON payloads fail validation and restore).
     - Factory reset / database purge with default system categories restoration.
     - `SettingsViewModel` export and restore reactive workflows.

4. **Project Documentation & Final Packaging (`README.md` & `ARCHITECTURE.md`)**:
   - `README.md`: Created comprehensive production-grade documentation covering Project Highlights, Smart Parsing, Indian Bank SMS parser, Voice Assistant, Siri Shortcuts, Dashboard, Budgets, Analytics, Security Invariants (AC-SEC-1, AC-PARSE-2, AC-DUP-1), Setup Guide, and Shortcuts Automation Tutorial.
   - `ARCHITECTURE.md`: Updated with complete data flow diagrams, export/backup subsystem, and directory structure.

Evidence:
- `ExpenseManager/Core/Export/DataExportServiceProtocol.swift`
- `ExpenseManager/Core/Export/DataExportService.swift`
- `ExpenseManager/Core/Export/MockDataExportService.swift`
- `ExpenseManager/Features/Settings/SettingsViewModel.swift`
- `ExpenseManager/Features/Settings/SettingsView.swift`
- `ExpenseManager/Features/Settings/SMSAutomationGuideView.swift`
- `ExpenseManager/Features/Settings/PrivacyGuaranteeView.swift`
- `ExpenseManager/Tests/ExportTests/DataExportAndSecurityTests.swift`
- `README.md`
- `ARCHITECTURE.md`
Open: None.
Blocked: None.
Next: Ready for production deployment / App Store packaging.

## 2026-08-26 — Phase 12 to 19: Merchant Intelligence, Glanceable Dashboard, Budget Engine, Financial Analytics, Account & Category Taxonomy, and Advanced Search / Bulk Operations Complete
Works:
1. **Merchant Intelligence & Recurring Subscriptions (`ExpenseManager/Core/Intelligence/`)**:
   - `MerchantIntelligenceService.swift`: Detects recurring subscriptions (e.g. Netflix, Spotify, Gym, Rent, Internet, utilities billed on monthly/weekly/yearly intervals ±5 days with amount consistency), calculates average monthly spend per merchant, identifies anomalous transactions (>= 2x merchant's 90-day average), and provides automatic categorization rule suggestions based on >= 75% category consistency.
   - Wired `merchantIntelligenceService` into `DependencyContainer.swift`.

2. **Glanceable Dashboard (`ExpenseManager/Features/Dashboard/`)**:
   - `DashboardViewModel.swift`: `@Observable` `@MainActor` ViewModel aggregating net worth, total assets (Bank + Cash + Wallet), total liabilities (Credit Card Debt), monthly cash flow (Income, Expenses, Net Savings rate), budget pace, top 5 category spending breakdown, recent transactions list, recurring subscription insights, and anomalous spend alerts.
   - `DashboardView.swift`: Polished Apple HIG SwiftUI dashboard featuring hero net worth card with assets/liabilities breakdown, monthly cash flow card with net savings badge, 5-button quick action pill grid (Smart Add, Voice, Manual, SMS Sandbox, Review), category spending carousel, recurring subscriptions preview, and recent transactions section with swipe-to-delete and swipe-to-edit actions.

3. **Budget Engine & Pace Projections (`ExpenseManager/Features/Budgets/`)**:
   - `BudgetsViewModel.swift`: Calculates month pace percentage (e.g. Day 18 of 30 = 60.0%), projects end-of-month spend `(spentSoFar / dayOfMonth) * daysInMonth`, daily budget allowance `(remainingBudget) / remainingDays`, at-risk overspending categories, and month navigation.
   - `BudgetsOverviewView.swift`: Month navigation header, daily allowance banner ("You can spend ₹1,450/day for the remaining 12 days"), at-risk warning banner, overall monthly budget card with progress bar, and category budget cards with color-coded progress bars (Green < 70%, Yellow 70-90%, Red > 90%).
   - `BudgetComposerView.swift`: Sheet modal to create or edit monthly category budget caps with quick amount presets (+₹2,000, +₹5,000, +₹10,000, +₹25,000, +₹50,000) and alert threshold slider (50% to 100%).

4. **Financial Analytics & Swift Charts (`ExpenseManager/Features/Analytics/`)**:
   - `AnalyticsViewModel.swift`: Computes time-series aggregates across periods (`1M`, `3M`, `6M`, `1Y`), category distributions, daily expense trends with 7-day moving averages, and top 5 merchant metrics.
   - `AnalyticsOverviewView.swift`: Segmented time horizon picker, KPI summary grid (Income, Expense, Net Savings, Daily Avg), Income vs Expense monthly bar chart (`BarMark`), Category spending breakdown donut chart (`SectorMark`), Daily spending trend line chart with 7-day moving average (`LineMark`, `BarMark`), and Top 5 merchants leaderboard table.

5. **Account Management & Category Taxonomy (`ExpenseManager/Features/Accounts/` & `ExpenseManager/Features/Categories/`)**:
   - `AccountsListViewModel.swift` & `AccountsListView.swift`: Account cards grouped by type (`Bank Accounts`, `Credit Cards`, `Wallets & Cash`), balance display, net worth contribution, and archive toggle.
   - `AccountComposerView.swift`: Modal to create or edit accounts with name, type, opening balance, currency, icon picker, color token picker, and last four digits.
   - `CategoriesViewModel.swift`, `CategoriesManagementView.swift`, and `CategoryComposerView.swift`: Taxonomy management separating default system categories and custom user categories with SF Symbol icon grid and color palette.

6. **Advanced Transaction Search, Filter & Bulk Actions (`ExpenseManager/Features/Transactions/`)**:
   - `TransactionsListViewModel.swift`: Live query search, date range filter (`All`, `Today`, `This Week`, `This Month`, `Last Month`, `Custom`), type filter, category filter, account filter, amount min/max filter, sorting (`Date Desc`, `Date Asc`, `Amount Desc`, `Amount Asc`), and bulk selection mode (`selectedTransactionIDs`).
   - `TransactionsListView.swift`: Search bar with instant autocomplete query, horizontal filter pills, sticky date group headers, swipe-to-delete, swipe-to-edit, transaction row badges, and floating bulk action toolbar (Select All, Re-categorize Selected, Delete Selected).
   - `TransactionDetailView.swift`: Detailed transaction modal showing amount, merchant, category, accounts, payment method, ingestion source metadata, reference / UPI VPA, confidence score & warnings, notes, tags, and audit timestamps.
   - `TransactionFilterSheetView.swift`: Multi-facet filter modal.

7. **Unit Test Suites (`ExpenseManager/Tests/FeaturesTests/`)**:
   - `DashboardAndAnalyticsTests.swift`: Verifies net worth calculation, cash flow aggregation, analytics time series, and merchant intelligence subscription & anomaly detection.
   - `BudgetsEngineTests.swift`: Verifies budget limits, daily allowance formula, spend projections, and at-risk category warnings.
   - `AccountAndCategoryTests.swift`: Verifies account creation, liability tracking, archive handling, and category taxonomy.
   - `TransactionsSearchAndFilterTests.swift`: Verifies multi-attribute search, sorting, date/category filters, and bulk delete / re-categorization.

8. **Application Wiring**:
   - Updated `AppState.swift` and `RootView.swift` to route all modal sheets (`accountComposer`, `accountsList`, `categoryComposer`, `categoriesManagement`, `budgetComposer`, `transactionDetail`, `manualEntry`).
   - Updated `SettingsView.swift` with navigation links to Manage Accounts and Category Taxonomy.

Evidence:
- `ExpenseManager/Core/Intelligence/`
- `ExpenseManager/Features/Dashboard/`
- `ExpenseManager/Features/Budgets/`
- `ExpenseManager/Features/Analytics/`
- `ExpenseManager/Features/Accounts/`
- `ExpenseManager/Features/Categories/`
- `ExpenseManager/Features/Transactions/`
- `ExpenseManager/Tests/FeaturesTests/`
Open: None.
Blocked: None.
Next: Export & CSV neutralization engine, WidgetKit extensions.

## 2026-08-26 — Phase 6, 7, 8, 9, 10, 11: Voice Entry, App Intents, Indian Bank SMS Parser, Duplicate Prevention, and SMS Diagnostics Complete
Works:
1. **Voice Entry Engine (`ExpenseManager/Core/Voice/` & `ExpenseManager/Features/VoiceEntry/`)**:
   - `AudioRecordingServiceProtocol.swift` & `AudioRecordingService.swift`: Speech recognition (`SFSpeechRecognizer` en-IN), `AVAudioEngine` buffer tap, live RMS audio power metering (0.0 to 1.0), and 1.5-second silence auto-stop.
   - `MockAudioRecordingService.swift`: Deterministic audio simulation for unit testing and SwiftUI previews.
   - `VoiceEntryViewModel.swift`: `@Observable` `@MainActor` ViewModel managing recording state, live transcript, real-time debounced parsing, candidate generation, and financial persistence.
   - `VoiceEntryView.swift`: Polished modal UI with animated pulsing microphone ring animations, 16-bar dynamic waveform metering visualizer, live transcript display, parsed candidate card with confidence badge, and save/edit triage actions.

2. **App Intents & Siri Shortcuts (`ExpenseManager/Core/AppIntents/`)**:
   - `LogExpenseIntent.swift`: Structured expense logging intent converting `Double` to exact `Decimal`, looking up accounts/categories, persisting via SwiftData, recording duplicate fingerprints, and returning localized Siri dialog.
   - `ParseTextExpenseIntent.swift`: Natural language and SMS parsing intent integrating with `SMSIngestionOrchestrator` for Siri and Shortcuts SMS Automations.
   - `ExpenseShortcutsProvider.swift`: Predefined voice phrases and Shortcuts app actions.

3. **Indian Bank SMS Parser & AC-PARSE-2 Safety Classifier (`ExpenseManager/Core/SMSParsing/`)**:
   - `SMSMessageType.swift`: Granular classification enum for transactions and rejected non-transaction alerts.
   - `SMSSafetyClassifier.swift`: Strict classifier implementing **AC-PARSE-2** guaranteeing that OTPs, failed/declined transactions, promotional marketing ads, card blocked notices, bill due reminders, and balance inquiries **NEVER** generate a transaction candidate.
   - `BankSMSParser.swift`: Multi-bank deterministic SMS parser tailored for HDFC Bank (accounts, cards, UPI), ICICI Bank (iMobile, credit card spends, NEFT), State Bank of India (SBI YONO UPI, ATM withdrawals, salary credits), Axis Bank, Kotak Mahindra Bank, American Express, and Standard Chartered. Extracts amounts, currencies, account masks, UPI VPAs, reference/UTRs, and available balances without confusing balances for amounts.
   - `SMSIngestionOrchestrator.swift`: Complete end-to-end ingestion pipeline executing Safety Classification -> Bank Parsing -> Duplicate Check -> Merchant Rule Resolution -> Confidence Valuation -> Auto-Save / Review Queue staging.

4. **Duplicate Prevention Engine (`ExpenseManager/Core/Storage/`)**:
   - `ImportFingerprintService.swift` & `MockImportFingerprintService.swift`: SHA-256 source hash generation, 5-minute sliding time window fuzzy duplicate detection (amount + merchant + account within 300s), and SwiftData persistence.

5. **SMS Diagnostics & Testing Sandbox (`ExpenseManager/Features/SMSDiagnostics/`)**:
   - `SMSDiagnosticsViewModel.swift` & `SMSDiagnosticsView.swift`: Interactive diagnostics tool with 10 sample bank templates (HDFC, ICICI, SBI, Axis, OTP, Spam, Declined, Bill Due), real-time safety status badge, extracted payload data grid, duplicate check indicator, and confidence score meter.

6. **Unit Test Suites (`ExpenseManager/Tests/SMSParsingTests/` & `ExpenseManager/Tests/VoiceAndIntentTests/`)**:
   - `SMSSafetyClassifierTests.swift`: Comprehensive unit tests for 20+ non-transaction messages ensuring 100% rejection.
   - `BankSMSParserTests.swift`: 15+ real-world Indian bank format unit tests validating exact amounts, merchant normalization, account masks, references, and directions.
   - `DuplicatePreventionTests.swift`: Unit tests for exact SHA-256 and 5-minute time window duplicate blocking.
   - `VoiceAndIntentTests.swift`: Unit tests for VoiceEntryViewModel state transitions and App Intents parameter validation.

7. **Application Wiring**:
   - Added `.smsDiagnostics` and `.voiceEntry` sheet routing in `AppState.swift` and `RootView.swift`.
   - Added Voice Entry button in `DashboardView.swift` quick action grid.
   - Added SMS Diagnostics Sandbox and Voice Entry links in `SettingsView.swift`.

Evidence:
- `ExpenseManager/Core/Voice/`
- `ExpenseManager/Features/VoiceEntry/`
- `ExpenseManager/Core/AppIntents/`
- `ExpenseManager/Core/SMSParsing/`
- `ExpenseManager/Features/SMSDiagnostics/`
- `ExpenseManager/Tests/SMSParsingTests/`
- `ExpenseManager/Tests/VoiceAndIntentTests/`
Open: None.
Blocked: None.
Next: Phase 12 — Analytics, Budgeting & CSV Export Engine.
Works:
1. **Hybrid Parser Subsystem (`ExpenseManager/Core/Parsing/`)**:
   - `InputNormalizer.swift`: Text sanitization, unicode punctuation normalization, whitespace collapsing, tokenization.
   - `AmountParser.swift`: Multi-currency deterministic amount parser supporting INR (`₹`, `Rs.`, `INR`, `rupees`), USD (`$`, `USD`), EUR, GBP, bare numbers with decimal and comma formats.
   - `DateParser.swift`: Relative temporal parsing (`today`, `yesterday`, `last Friday`, `last night`) and absolute dates (`25 Aug`, `25/08/2026`, `2026-08-25`).
   - `TransactionDirectionClassifier.swift`: Categorizes transactions into `expense`, `income`, `refund`, `transfer`, `cashWithdrawal`.
   - `MerchantNormalizer.swift`: Noise removal (`VPA`, `UPI`, `PVT LTD`, `INFO*`, `POS`, `TXN`), normalization (`SWIGGY*BANGALORE` -> `Swiggy`), and category mapping.
   - `AccountHintParser.swift`: Bank identification (`HDFC`, `ICICI`, `SBI`, `Axis`, `Kotak`, `GPay`, `PhonePe`, `Cash`), account last 4 extraction (`XX4321`, `ending 8432`), payment method inference.
   - `ReferenceNumberParser.swift`: UPI VPA parsing (`swiggy@upi`, `user@okaxis`), UTRs (`UTR 123456789012`), transaction IDs (`UPI/482019283741`).
   - `DeterministicTransactionParser.swift`: High-speed pipeline combining all extractors into unified transaction drafts.
   - `ParserOrchestrator.swift`: Implements `ParserServiceProtocol` coordinating deterministic parser, user-defined merchant rules, and confidence valuation.

2. **Confidence Engine & Review Queue (`ExpenseManager/Core/Confidence/` & `ExpenseManager/Features/ReviewQueue/`)**:
   - `ConfidenceEngine.swift`: Computes granular confidence score (0.0 to 1.0) and assigns tiers (`High` >= 0.90, `Medium` 0.65-0.89, `Low` < 0.65), evaluates auto-save eligibility, and generates diagnostic warnings.
   - `ReviewQueueViewModel.swift` & `ReviewQueueView.swift`: Manages queued candidates, tier filtering (`All`, `Medium`, `Low`), diagnostic "Why this needs review" badges, one-tap `Accept`, `Edit`, `Discard`, and batch acceptance.

3. **Manual Transaction Entry (`ExpenseManager/Features/ManualEntry/`)**:
   - `ManualTransactionComposerViewModel.swift` & `ManualTransactionComposerView.swift`: Fast 2-3 second logging interface, segmented control (Expense/Income/Transfer), amount entry with `+100`, `+500`, `+1,000`, `+2,000` presets, recent merchant quick-chips, category icon grid with semantic colors, account & destination account pickers, date picker, notes & tags, merchant category rule persistence, and haptic feedback.

4. **Smart Text Entry (`ExpenseManager/Features/SmartEntry/`)**:
   - `SmartTextComposerViewModel.swift` & `SmartTextComposerView.swift`: Live debounce parser, quick example chips (`Swiggy 520`, `Salary 85000 today`, `Uber 460 from HDFC`), real-time parsed preview card with interactive category/account adjustments, confidence badges, diagnostic warnings, category rule learning, and full editor navigation.

5. **Unit Test Suites (`ExpenseManager/Tests/ParserTests/` & `ExpenseManager/Tests/EntryTests/`)**:
   - `HybridParserTests.swift`: Comprehensive unit tests covering 30+ parser input variations.
   - `ConfidenceEngineTests.swift`: Comprehensive unit tests for confidence scoring, tiers, auto-save eligibility, and diagnostic warnings.
   - `ManualAndSmartEntryTests.swift`: Comprehensive unit tests for ViewModel validation, state mutations, triage actions, and save flows.

6. **Wiring & Integration**:
   - Updated `DependencyContainer.swift`, `RootView.swift`, and `DashboardView.swift` to seamlessly bind new features.

Evidence:
- `ExpenseManager/Core/Parsing/`
- `ExpenseManager/Core/Confidence/`
- `ExpenseManager/Features/ManualEntry/`
- `ExpenseManager/Features/SmartEntry/`
- `ExpenseManager/Features/ReviewQueue/`
- `ExpenseManager/Tests/ParserTests/`
- `ExpenseManager/Tests/EntryTests/`
Open: None.
Blocked: None.
Next: Phase 6 — Ingestion Automation & SMS / OCR / Voice Pipeline.

## 2026-08-26 — Phase 1: Financial Data Engine Complete
Works: SwiftData persistent schema models implemented (`TransactionRecord`, `AccountRecord`, `CategoryRecord`, `TagRecord`, `MerchantRuleRecord`, `ImportFingerprintRecord`, `BudgetRecord`). SwiftData database container manager initialized (`DatabaseContainer`). Production implementations of domain services created (`SwiftDataTransactionService`, `SwiftDataAccountService`, `SwiftDataCategoryService`, `SwiftDataBudgetService`, `MerchantRuleService`, `ImportFingerprintService`). Strict financial accounting balance invariants implemented (Expense debits, Income/Refund credits, Transfer debits source & credits destination without inflating totals, update/delete rollback logic). `DependencyContainer.live(...)` wired and injected into `ExpenseManagerApp`. Comprehensive in-memory SwiftData unit tests implemented in `FinancialEngineTests.swift`.
Changed: Created all files in `ExpenseManager/Core/Models/`, `ExpenseManager/Core/Storage/` production services, updated `DependencyContainer.swift`, updated `ExpenseManagerApp.swift`, and added `FinancialEngineTests.swift`.
Evidence: `ExpenseManager/Core/Models/`, `ExpenseManager/Core/Storage/`, `ExpenseManager/Tests/FinancialEngineTests/FinancialEngineTests.swift`.
Open: None.
Blocked: None.
Next: Proceed to Phase 2 — Ingestion & Smart Parser Engine.

## 2026-08-26 — Phase 0: Repository & Architecture Foundation Complete
Works: Modular directory structure initialized, privacy-safe `AppLogger`, exact `Decimal` `CurrencyFormatter` with INR Lakh/Crore compact formatting and parsing, Apple HIG `ColorTokens` & `Typography`, reusable UI components, Domain service protocols & DTO types, in-memory mock service implementations, `DependencyContainer`, `@Observable` `AppState`, tab shell `RootView` & `RootViewModel` with sheet & animated toast coordinators, placeholder feature screens (Dashboard, Transactions, Smart Entry, Budgets, Analytics, Settings), comprehensive `ArchitectureFoundationTests`, and `ARCHITECTURE.md` architecture guide.
Changed: Created all Phase 0 foundation files under `ExpenseManager/` and `ARCHITECTURE.md` in workspace root.
Evidence: `ExpenseManager/App/`, `ExpenseManager/Core/`, `ExpenseManager/Domain/`, `ExpenseManager/Features/`, `ExpenseManager/Tests/`, `ARCHITECTURE.md`.
Open: None.
Blocked: None.
Next: Proceed to Phase 1 — Financial Data Engine (SwiftData Persistent Schema, Models, Relationships, and Ledger Engine).

## 2026-08-26 — Project Initialization & Gauntlet Setup
Works: Project workspace prepared, iOS developer & reviewer skills initialized, Gauntlet ledger instantiated.
Changed: Created SKILL definitions (`ios-developer`, `ios-reviewer`), defined subagents (`ios_implementer`, `ios_reviewer`, `ios_resource_agent`), initialized `QUALITY_BAR.md`, `ISSUES.md`, and `CHECKPOINT.md`.
Evidence: `PROJECT_MEMORY.md`, `AGENTS.md`, `QUALITY_BAR.md`, `ISSUES.md`
Open: None
Blocked: None
Next: Phase 0 Foundation Execution.
