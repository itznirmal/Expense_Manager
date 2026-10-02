# Expense Manager for iOS

A local spending tracker for **everyday expenses with optional budgets**. The current direction emphasizes quick entry, understandable spending, and control over your records.

## Product and handoff

- [Assessment, implementation lessons and iOS product brief](docs/Expense_Tracker_iOS_Rebuild_Brief.md)
- [Current implementation status and verification limits](docs/Brief_Implementation_Status.md)
- [MacBook setup, simulator tests and device acceptance checks](docs/MacBook_Verification_Guide.md)

The brief is implemented in the existing iOS source. The original assessment is historical. Release readiness requires successful native builds/tests and observed device behavior; older readiness claims elsewhere in the repository are not current proof.

## Current source

- **Today:** recorded net spending for a selected currency, category breakdown, recent entries and a prominent Add expense action.
- **History:** search, filters, edit/delete and split entries.
- **Plan:** optional monthly/category limits, remaining recorded budget and pace estimates.
- Short first-use currency choice; amount/category entry with optional details. Accounts, signup, budgets and permissions are not required to record an ordinary expense.
- Decimal monetary values, currency precision validation, posted/review state, separate currency summaries and refunds reducing net spending.
- Local SwiftData storage, optional device-authenticated App Lock, inactive privacy cover, sanitized CSV export and versioned JSON backup/restore.
- Retained secondary smart-text, voice, bank-message Shortcuts, CSV import, accounts and widgets. These require their native/device acceptance checks before release.

No bank connection, cloud account, FX conversion or sync is introduced. JSON backups use a damage-detection checksum and are not encrypted or digitally signed. Voice requires supported on-device recognition. iOS does not grant this app arbitrary access to the Messages inbox; bank-message input is user-provided or passed through a configured Shortcut. App Lock requires these captures to happen inside the app. Financial widget values are hidden by default.

## Build on a Mac

Requires Xcode 16.4 or newer, XcodeGen, and an installed iOS simulator. Deployment target: iOS 17. `project.yml` generates the app, widget, unit-test and UI-test targets with Swift 6 and strict concurrency checking.

```bash
brew install xcodegen
bash scripts/verify-ios.sh
open ExpenseManager.xcodeproj
```

Choose the ExpenseManager scheme and an iPhone simulator. For a real iPhone, configure the development team and matching App Group for both app and widget. See the [MacBook guide](docs/MacBook_Verification_Guide.md) for details and recovery steps.

GitHub Actions runs the same verification script on macOS 15 / Xcode 16.4 and preserves logs plus `.xcresult` artifacts. A workflow being configured does not imply it passed. Local Windows work is source-only.

## Structure

| Path | Responsibility |
|---|---|
| `ExpenseManager/App` | Bootstrap, application state, privacy and navigation |
| `ExpenseManager/Domain` | Decimal DTOs, transaction candidates, service contracts |
| `ExpenseManager/Core/Storage` and `Core/Models` | SwiftData ledger, posting rules and schema migration |
| `ExpenseManager/Core/Parsing`, `SMSParsing`, `Voice`, `AppIntents` | Optional capture adapters |
| `ExpenseManager/Core/Export` | CSV, validated backup/restore and statement import |
| `ExpenseManager/Features` | Native SwiftUI flows and observable view models |
| `ExpenseManagerWidgets` | Widget extension and consent-gated summaries |
| `ExpenseManager/Tests`, `ExpenseManagerUITests` | Financial, recovery, parser, security and UI regressions |
| `docs`, `evidence`, `CHECKPOINT.md`, `ISSUES.md` | Brief, acceptance status and recorded evidence |

The original `QUALITY_BAR.md` is frozen. The new brief/status clarifies current scope. Merged historical issue IDs overlap; new work uses `BRIEF-*` IDs. Future changes should preserve data and complete the build/run/observe/review cycle before claiming release readiness.
