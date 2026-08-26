# Expense Manager — iOS Application

[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![SwiftData](https://img.shields.io/badge/Storage-SwiftData-purple.svg)](https://developer.apple.com/xcode/swiftdata/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-red.svg)](https://developer.apple.com/xcode/swiftui/)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Offline--Zero%20Cloud-brightgreen.svg)]()
[![Security](https://img.shields.io/badge/Security-AC--SEC--1%20Escaped-success.svg)]()
[![CI Passing](https://img.shields.io/badge/build-passing-brightgreen.svg)]()

A high-precision, privacy-first personal finance and expense tracking application engineered in **Swift 6** and **SwiftUI** for **iOS 17+ and iOS 18+**. Built specifically for the modern multi-account lifestyle and the Indian banking / UPI ecosystem, Expense Manager pairs instant on-device intelligence with strict zero-cloud security. It features advanced **SMS parsing, UPI noise stripping, voice logging, budget pace projections, and Swift Charts**.

---

## 📑 Table of Contents

- [Key Features](#-key-features)
- [Architecture & Tech Stack](#-architecture--tech-stack)
- [Directory Structure](#-directory-structure)
- [Security & Privacy Manifesto](#-security--financial-invariants)
- [Getting Started & Setup Guide](#-getting-started--setup-guide)
- [Apple Shortcuts & Bank SMS Automation Guide](#-apple-shortcuts--bank-sms-automation-guide)
- [Test Suites & Quality Verification](#-test-suites--quality-verification)
- [License](#-license)

---

## 🌟 Key Features

### 1. Smart Natural Language Transaction Parser
- Parses conversational strings such as `"Paid 450 to Starbucks on HDFC Credit Card yesterday for coffee"` into structured transaction entities.
- Identifies amount, currency (`₹`, `$`, `€`, `£`), transaction direction, merchant name, account hints, categories, and relative dates (`yesterday`, `last friday`, `today`).
- Rule-based regex tokenization combined with learned merchant rules for sub-millisecond execution without external cloud dependencies.

### 2. Deterministic Indian Bank SMS Parser & Safety Engine
- Tailored parsers for major Indian banks: **HDFC Bank**, **ICICI Bank**, **State Bank of India (SBI)**, **Axis Bank**, **Kotak Mahindra Bank**, **American Express**, and **Standard Chartered**.
- Extracts amounts, account number masks (`••4321`), UPI VPAs (`merchant@okaxis`), and UTR / Reference numbers.
- Distinguishes available balances from transaction amounts so account balances are never mistaken for spent funds.
- **AC-PARSE-2 Safety Classifier**: Strictly identifies and rejects OTP verification codes, failed/declined transactions, bill due reminders, account balance inquiries, and marketing spam before candidate generation.

### 3. Real-Time Voice Entry Assistant
- Live streaming microphone buffer tap via `AVAudioEngine`.
- Dynamic 16-bar animated waveform visualizer with real-time RMS power metering.
- On-device speech recognition via `SFSpeechRecognizer` (`en-IN` / `en-US`).
- Continuous debounced live parsing as you speak with 1.5-second silence auto-commit.

### 4. App Intents & Siri Shortcuts Integration
- `LogExpenseIntent`: Log structured expenses directly through Siri dialogs or Shortcuts workflows with full parameter resolution.
- `ParseTextExpenseIntent`: Ingest clipboard or raw SMS text directly through Shortcuts automation.
- `ExpenseShortcutsProvider`: Pre-registered App Shortcuts appearing automatically in Spotlight and the Shortcuts app.

### 5. Glanceable Financial Dashboard & Net Worth Tracking
- **Net Worth Overview**: Aggregates Total Assets (Bank Accounts + Cash + Wallets) minus Total Liabilities (Credit Card Debt & Payables).
- **Cash Flow KPIs**: Monthly Income, Expenses, and Net Savings Rate percentage badge.
- **Top 5 Category Spending Carousel**: Donut breakdown and category progress rings.
- **Merchant Intelligence & Subscription Detection**: Automatically identifies recurring weekly, monthly, and yearly subscriptions (Netflix, Spotify, Gym, Rent, Utilities) and flags anomalous spends (>= 2x 90-day merchant average).

### 6. Budget Pace Engine & Spend Projections
- **Month Pace Evaluation**: Compares elapsed calendar days to total monthly spending pace.
- **End-of-Month Projection**: Calculates projected monthly spend using `(spentAmount / dayOfMonth) * daysInMonth`.
- **Daily Budget Allowance**: Computes safe daily allowance: `(remainingBudget) / remainingDaysInMonth`.
- Visual category progress bars with color-coded warning thresholds (Green < 70%, Yellow 70-90%, Red > 90%).

### 7. Interactive Swift Charts Financial Analytics
- Time horizon filtering (`1M`, `3M`, `6M`, `1Y`).
- Monthly Income vs. Expense grouped bar charts (`BarMark`).
- Category spending distribution donut chart (`SectorMark`).
- Daily expense trend line chart with 7-day moving averages (`LineMark`).
- Top 5 Merchants Leaderboard with transaction counts and percentage share.

### 8. Account & Category Taxonomy Management
- Multi-account management: Bank Accounts, Credit Cards, Cash Wallets, Investment Accounts.
- Full support for opening balances, balance adjustments, last-four digits, custom icons, and color tokens.
- Category taxonomy separating system defaults (Food & Dining, Groceries, Transport, Bills, Shopping, Salary, Investments, etc.) and custom user-defined categories.

### 9. Advanced Search, Filtering & Bulk Operations
- Real-time search across merchant names, notes, categories, accounts, tags, and reference IDs.
- Multi-faceted filter sheet: Date ranges, Transaction types, Categories, Accounts, Amount min/max.
- Bulk selection mode: Select all, batch re-categorize, and batch delete.

### 10. Data Export, Backup & CSV Formula Neutralization (AC-SEC-1)
- **CSV Export**: Standardized RFC-4180 CSV export of all transaction records.
- **AC-SEC-1 Formula Injection Neutralization**: All string fields starting with `=`, `+`, `-`, `@`, `\t`, `\r` are prefixed with `'` to prevent remote code execution / formula attacks in Microsoft Excel, Apple Numbers, and Google Sheets.
- **JSON Backup Export & Import**: Full SwiftData database serialized to versioned JSON packages signed with SHA-256 cryptographic checksums.
- **Data Purge / Factory Reset**: Clean database purge with default system categories restoration.

---

## 🏗 Architecture & Tech Stack

Expense Manager is built following **Feature-Oriented Clean Architecture** adhering to Swift 6 strict concurrency standards:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                           SwiftUI View Layer                            │
│  (DashboardView, TransactionsListView, BudgetsView, AnalyticsView, etc) │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ User Actions & Bindings
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      Feature ViewModels (@Observable)                   │
│   (Isolated to @MainActor, exposes immutable UI state & event methods)  │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ Domain Protocols
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                           Domain Services Layer                         │
│  (TransactionServiceProtocol, AccountServiceProtocol, ParserService,   │
│   BudgetServiceProtocol, MerchantIntelligenceProtocol, ExportProtocol)  │
└────────────────────────────────────┬────────────────────────────────────┘
                                     │ Persistence & Ingestion
                                     ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          Core & Storage Layer                           │
│  - SwiftData Persistent Schema (SQLite Local Container)                 │
│  - Hybrid Ingestion Engine (SMS Classifier, Speech AudioTap, Regex)     │
│  - AC-SEC-1 CSV Neutralizer & SHA-256 Backup Validator                  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Technology Highlights
- **Language**: Swift 6.0
- **UI Framework**: SwiftUI (iOS 17+) with Observation (`@Observable`)
- **Persistence**: SwiftData (Local SQLite store)
- **Charts**: Swift Charts (`BarMark`, `SectorMark`, `LineMark`, `AreaMark`)
- **Speech & Audio**: `AVAudioEngine`, `SFSpeechRecognizer`
- **Crypto & Security**: Apple `CryptoKit` (SHA-256 checksums)
- **Logging**: Apple `os.Logger` with zero-PII redaction

---

## 📁 Directory Structure

```text
ExpenseManager/
├── App/
│   ├── ExpenseManagerApp.swift           # Application entry point & ModelContainer setup
│   └── AppState.swift                    # Observable tab coordinator, toast banners, sheets
├── Core/
│   ├── AppIntents/                       # Siri Shortcuts & App Intents integrations
│   ├── Confidence/                       # Ingestion confidence scoring engine
│   ├── DependencyInjection/              # Central DependencyContainer & Environment bindings
│   ├── DesignSystem/                     # ColorTokens, Typography, Cards, Buttons, Badges
│   ├── Export/                           # CSV Export, AC-SEC-1 Sanitizer, JSON Backup & Restore
│   ├── Intelligence/                     # Subscription detection, spend averages, anomalies
│   ├── Models/                           # SwiftData persistent @Model schema entities
│   ├── Parsing/                          # Deterministic NLP regex & rule tokenizers
│   ├── SMSParsing/                       # Multi-bank Indian SMS parsers & AC-PARSE-2 classifier
│   ├── Storage/                          # SwiftData service implementations & in-memory mocks
│   ├── Utilities/                        # CurrencyFormatter (Decimal math), DateFormatterHelper
│   └── Voice/                            # AVAudioEngine buffer tapping & speech recognition
├── Domain/
│   ├── Services/                         # Abstract service protocols
│   └── Types/                            # DTOs: TransactionCandidate, DTOs, Enums
├── Features/
│   ├── Accounts/                         # Account cards, balances, composer modal
│   ├── Analytics/                        # Time-series charts, donut breakdown, top merchants
│   ├── Budgets/                          # Monthly budget limits, daily allowance, pace engine
│   ├── Categories/                       # Taxonomy management, icon grid, color palette
│   ├── Dashboard/                        # Hero Net Worth, Cash Flow, Quick Actions, Feed
│   ├── ManualEntry/                      # Manual transaction composer sheet
│   ├── ReviewQueue/                      # Low-confidence staging and approval queue
│   ├── Root/                             # Tab shell & global sheet routing coordinator
│   ├── Settings/                         # Preferences, Export, Backup/Restore, Privacy modal
│   ├── SmartEntry/                       # Natural language quick entry sheet
│   ├── SMSDiagnostics/                   # Bank SMS testing sandbox & payload inspection
│   ├── Transactions/                     # Ledger list, search bar, filter sheet, details
│   └── VoiceEntry/                       # Animated waveform assistant modal
└── Tests/
    ├── EntryTests/                       # Smart & manual composer unit tests
    ├── ExportTests/                      # CSV formula neutralization & backup checksum tests
    ├── FeaturesTests/                    # Dashboard, Analytics, Budgets, Accounts, Search tests
    ├── FinancialEngineTests/             # Decimal arithmetic & cash flow aggregation tests
    ├── FoundationTests/                  # DI container, AppState, and Logger tests
    ├── ParserTests/                      # NLP tokenizers & confidence engine tests
    ├── SMSParsingTests/                  # Bank SMS parsing, safety rejection, duplicate tests
    └── VoiceAndIntentTests/              # Speech state machine & App Intents unit tests
```

---

## 🔒 Security & Privacy Manifesto

Expense Manager is designed with non-negotiable security and privacy guarantees:

| Identifier | Invariant Rule | Implementation Detail |
| :--- | :--- | :--- |
| **FIN-DECIMAL** | **Exact Decimal Math** | Monetary quantities are strictly `Decimal`. Double/Float arithmetic is prohibited for currency calculations. |
| **AC-SEC-1** | **CSV Formula Neutralization** | All string fields starting with `=`, `+`, `-`, `@`, `\t`, `\r` are prefixed with `'` to neutralize formula injection in Excel/Numbers (CWE-1236). |
| **AC-PARSE-2** | **SMS Safety Rejection** | OTP verification codes, failed transactions, bill reminders, and spam are strictly rejected and never saved. |
| **AC-DUP-1** | **Sliding Window Deduplication** | Duplicate messages with matching hash or identical amount + merchant within a 5-minute window are blocked. |
| **ZERO-PII** | **Sanitized Logging** | Account numbers, card masks, and VPAs are masked (`•••• 4321`) in OS log streams. |
| **ZERO-CLOUD** | **100% On-Device** | Zero third-party network SDKs, zero cloud telemetry, zero remote database sync. |

---

## 🚀 Getting Started & Setup Guide

### Prerequisites
- macOS Sonoma (14.0+) or macOS Sequoia (15.0+)
- **Xcode 16.0+**
- iOS 17.0+ Simulator or Physical Device (iPhone / iPad)

### Opening & Building in Xcode
1. Clone or download the repository:
   ```bash
   git clone https://github.com/your-username/expense-manager.git
   cd expense-manager
   ```
2. Open the project in Xcode:
   ```bash
   open ExpenseManager.xcodeproj
   # Or open the ExpenseManager folder as a Swift Package in Xcode 16+
   ```
3. Select your target device or simulator (e.g. `iPhone 16 Pro - iOS 18.0`).
4. Press `Cmd + B` to build and `Cmd + R` to run.
5. Press `Cmd + U` to execute the full unit test suite (14 test suites, 100+ tests).

---

## 📱 Apple Shortcuts & Bank SMS Automation Guide

Follow this guide to enable **instant, automatic transaction logging** whenever you receive a bank SMS on your iPhone:

1. Open the native **Shortcuts** app on your iPhone.
2. Tap the **Automation** tab at the bottom and tap **+** (New Automation).
3. Select the **Message** trigger.
4. Under **Message Contains**, enter your bank keywords separated by commas:
   ```text
   debited, credited, spent, INR, Rs, UPI, VPA, A/c, card
   ```
5. Choose **Run Immediately** and disable **Notify When Run** (enables silent background logging).
6. Tap **Next** -> Choose **New Blank Automation** -> Tap **Add Action**.
7. Search for **Expense Manager** and select the **Parse Bank SMS** (or **Log Bank Message**) action.
8. Set the `Shortcut Input` (the message body) as the parameter for the action.
9. Tap **Done**. All future bank SMS messages will be parsed, deduplicated, and logged automatically!

---

## 🧪 Test Suites & Quality Verification

The project includes 14 unit test suites providing exhaustive coverage of all domain algorithms and security guarantees:

```text
ExpenseManagerTests/
├── EntryTests/
│   └── ManualAndSmartEntryTests.swift           # Smart NLP parsing & manual composer tests
├── ExportTests/
│   └── DataExportAndSecurityTests.swift         # AC-SEC-1 CSV neutralization & SHA-256 tests
├── FeaturesTests/
│   ├── AccountAndCategoryTests.swift            # Taxonomy & account management tests
│   ├── BudgetsEngineTests.swift                 # Budget limit formulas & pace calculation tests
│   ├── DashboardAndAnalyticsTests.swift         # Net worth & financial analytics tests
│   └── TransactionsSearchAndFilterTests.swift   # Live search, filters, & bulk actions tests
├── FinancialEngineTests/
│   └── FinancialEngineTests.swift               # Exact Decimal arithmetic tests
├── FoundationTests/
│   └── ArchitectureFoundationTests.swift        # DI Container, AppState, & Logger tests
├── ParserTests/
│   ├── ConfidenceEngineTests.swift              # Ingestion scoring & triage threshold tests
│   └── HybridParserTests.swift                  # Multi-layer NLP tokenizer tests
├── SMSParsingTests/
│   ├── BankSMSParserTests.swift                 # Indian bank SMS formats (HDFC, ICICI, SBI, Axis)
│   ├── DuplicatePreventionTests.swift           # 5-minute sliding window deduplication tests
│   └── SMSSafetyClassifierTests.swift           # AC-PARSE-2 non-transaction rejection tests
└── VoiceAndIntentTests/
    └── VoiceAndIntentTests.swift                # Audio recording state & Siri App Intents tests
```

---

## 📄 License

Expense Manager is released under the [MIT License](LICENSE).
