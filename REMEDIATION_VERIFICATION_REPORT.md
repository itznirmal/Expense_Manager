# Expense Manager — Remediation Verification Report

**Verification date:** 2026-08-26  
**Original audit:** `REVIEW_REPORT.md`  
**Remediation report supplied:** `Comprehensive Audit Remediation & Verification Report`  
**Remediation commit:** `472505a`  
**Compared against:** `51d842c`  
**Final verdict:** **BLOCKING DEFECTS FOUND — REMEDIATION INCOMPLETE**

## Executive Summary

Gemini's remediation commit exists locally, is the current `HEAD`, and matches `origin/main`. It makes several valuable repairs, including removal of raw SMS text from newly ingested transaction notes, broader bank-date parsing, corrected income-before-transfer classification, edit-mode update routing, on-device speech configuration, padded CSV formula neutralization, and backup inclusion of import fingerprints.

The claim that all P0/P1/P2 findings are fixed is not supported by the repository. Release-blocking build/package, security, financial-integrity, persistence, review-queue, duplicate-prevention, restore, and multi-currency defects remain. The repository also contains no stored build, test, simulator, or device evidence. Only one test file changed, and the test target has a statically confirmed async call-site error.

The app should not be treated as production-ready or submitted to the App Store in this state.

## Scope and Method

The remediation was reviewed independently along three axes:

1. **Standards and architecture:** package/target viability, Swift/iOS conventions, privacy configuration, concurrency, and test compilation.
2. **Specification and feature closure:** each major original finding was classified as confirmed, partial, open, or unverified.
3. **Adversarial and corner cases:** failure paths, authentication bypasses, accounting invariants, rollback, duplicate races, restore failure, and cross-currency behavior.

The review was read-only. No production or test source was modified.

### Verification limitations

- This Windows host has no Swift or Xcode toolchain, iOS Simulator, signing environment, biometric runtime, App Intents runtime, or speech runtime.
- No `evidence/` directory or saved compiler/test/simulator output exists in the repository.
- `CHECKPOINT.md` contains no remediation build/run/observe/verify evidence.
- Therefore, static passes are not equivalent to a successful build or runtime verification.

## Release Blockers

### P0 — No runnable iOS application target

`Package.swift:12-24` defines a library product and regular target, not an iOS application bundle. The app entry point is inside that library at `ExpenseManager/App/ExpenseManagerApp.swift:12`, and there is still no `.xcodeproj`, `.xcworkspace`, application target, entitlements configuration, asset/signing setup, or installable product.

`Package.swift:24` also excludes `Info.plist`, so the new microphone, speech, and Face ID usage descriptions are not attached to an application target. The README still instructs users to open a nonexistent Xcode project.

The package declares macOS 14 while source such as `AudioRecordingService.swift` uses unguarded iOS-only `AVAudioSession` APIs. The declared macOS target is therefore not viable as written.

**Status:** OPEN. Adding a manifest and plist file did not establish a buildable, installable iOS app.

### P1 — Test target contains a confirmed compile error

`ReviewQueueViewModel.discardCandidate` is now async at `ExpenseManager/Features/ReviewQueue/ReviewQueueViewModel.swift:114`, but `ExpenseManager/Tests/EntryTests/ManualAndSmartEntryTests.swift:165` calls it without `await`.

**Status:** OPEN. The advertised 126 tests cannot be accepted as passing evidence.

### P1 — Biometric lock fails open

`ExpenseManager/App/AppState.swift:127-131` explicitly sets `isBiometricallyLocked = false` when neither biometric nor device-owner authentication can be evaluated. A persisted enabled lock can therefore expose financial data on an unsupported or unconfigured device.

`ExpenseManager/Features/Root/RootView.swift:38-42` relocks only on `.background`, not `.inactive`, leaving an app-switcher/control-center exposure window. The app injects `AppState` through type-based environment injection while consumers use a custom environment key with its own default `AppState`, so the ownership/wiring is also inconsistent.

**Status:** OPEN/PARTIAL. Root gating exists, but the required fail-closed invariant is violated.

### P1 — Transfers and ATM cash can remain one-sided

`SwiftDataTransactionService` declares `transferMissingDestination` but never enforces it. The service permits nil or identical source/destination accounts, and credits the destination only when resolution succeeds (`ExpenseManager/Core/Storage/SwiftDataTransactionService.swift:84-111,224-241`).

Manual validation exists only in the UI. SMS transfer candidates synthesize the name `"Savings Account"`, which may not resolve. ATM/cash-withdrawal candidates can debit the bank account without crediting a cash account, including when the manual fallback string `"Cash"` resolves to nothing.

**Status:** OPEN. The domain service must enforce source, destination, distinct-account, and cash-destination invariants for every input channel.

### P1 — Ledger rollback is not transaction-safe

Create attempts balance compensation on save failure. Update and delete failure paths do not restore all mutated/deleted model-context state, and no `modelContext.rollback()` exists. Update can also fail after reversing the old balance but before entering its save-compensation block (`SwiftDataTransactionService.swift:127-198`).

**Status:** PARTIAL/OPEN. Compensating balance arithmetic is not equivalent to atomic persistence.

### P1 — Review queue corrupts accounting state and does not close accepted items

Low-confidence SMS items are persisted through the normal transaction service before approval (`SMSIngestionOrchestrator.swift:157-174`), immediately affecting balances and normal transaction views.

`TransactionRecord` has no persisted accepted/review status. Reload reconstructs `needsReview` from confidence, while acceptance leaves confidence unchanged; accepted low-confidence records can reappear. Acceptance catches any update error and attempts create, which can mask persistence errors and duplicate transactions. Production sample queue items remain. Discard suppresses delete errors and still reports success.

The queue also uses `0.85` for bulk acceptance while the quality bar requires `0.90`.

**Status:** OPEN. Pending review must be represented durably without affecting the ledger until acceptance.

### P1 — Duplicate prevention remains race-prone

SMS ingestion performs check-then-create-then-record across separate operations (`SMSIngestionOrchestrator.swift:91-109,142-172`). `ImportFingerprintRecord.sourceHash` is not unique, and fingerprint persistence failures are swallowed with `try?`.

Concurrent ingestion can therefore create duplicates, and a saved transaction can exist without its fingerprint. Account-last-four matching is also weakened because the orchestrator passes bank/account suggestions rather than reliably preserving the parsed masked digits.

**Status:** OPEN. Fingerprint uniqueness and transaction creation need one atomic persistence boundary.

### P1 — Restore remains destructive and non-atomic

Fingerprints are now included in backup export and restore. However, restore still deletes the live store and rebuilds it in the same context before a single save (`DataExportService.swift:260-405`). A mid-restore decode/reference/insert/save failure has no staging-store swap or rollback.

The backup schema version remains 1 while `importFingerprints` is a new non-optional decoded field, so older version-1 backups that lack the key may no longer decode.

**Status:** PARTIAL/OPEN. Data coverage improved; atomicity and backward compatibility did not.

### P1 — Multi-currency totals are still mathematically invalid

The account service now groups balances by currency, but its scalar net-worth function returns only the default currency or an arbitrary first currency. Dashboard, account-list, and transaction summaries still directly add amounts from different currencies (`DashboardViewModel.swift:91-109`, `AccountsListViewModel.swift:48-77`, `SwiftDataTransactionService.swift:200-219`).

**Status:** OPEN. Totals must either remain currency-separated or use an explicit exchange-rate policy with timestamp/source disclosure.

## Partial or Incomplete Feature Repairs

### Account resolution

Direct ID, exact name, last-four, and fuzzy lookup were added. However, `BankSMSParser` still reduces its account hint to the bank name in the live path, so the new last-four lookup may never receive the information it needs. Ambiguous last-four/fuzzy matches are resolved by first match rather than requiring review.

**Status:** PARTIAL.

### Account balance editing

The edit path now passes and saves the balance. `updateAccount` writes the edited value to both `currentBalance` and `openingBalance`, rewriting historical opening state rather than recording an auditable adjustment.

**Status:** PARTIAL.

### App Intent

`LogExpenseIntent` now uses the canonical transaction service and reports transaction-save failures. Its public amount remains `Double`, so converting to `Decimal` after input cannot recover precision already lost. Fingerprint failures remain swallowed, and repeated invocations are not atomically deduplicated.

**Status:** PARTIAL.

### Speech entry

On-device recognition is requested and recording is stopped on view disappearance. The code does not first verify `supportsOnDeviceRecognition`, permission/error reporting is incomplete, and runtime lifecycle tests were not added.

**Status:** STATIC FIX CONFIRMED; RUNTIME UNVERIFIED.

### Bank dates and transaction direction

New date formats such as `25-AUG-26`, `25-Aug-26`, and `25Aug26` are covered in the parser, and income is checked before transfer. Existing fixtures do not assert the parsed dates, and there is no ledger integration test proving incoming NEFT/salary credits the correct account. Broad credit keywords can still misclassify a genuine incoming self-transfer.

**Status:** STATIC FIX CONFIRMED; INTEGRATION UNVERIFIED.

## Confirmed Improvements

The following changes are present and directionally correct:

- New live SMS ingestion candidates set `notes: nil`, preventing raw bank message text from being saved in normal transaction notes.
- CSV formula neutralization checks trimmed leading whitespace/control padding, with a new regression assertion.
- Manual edit mode preserves the candidate ID and calls update rather than always creating.
- Transaction and related call sites were substantially migrated away from stale internal APIs.
- Delete errors in transaction detail are no longer universally shown as success.
- Import fingerprints are included in new backup payloads and restore insertion.
- On-device speech recognition is explicitly requested, and recording is stopped when the voice-entry view disappears.
- Account resolution has direct ID, exact name, last-four, and fuzzy strategies.
- The remediation commit and its push to `origin/main` are verified.

These improvements do not offset the open blockers above.

## Remaining P2 Specification Gaps

Gemini's claim that all P2 items are fixed is also incorrect:

- Category edit/delete is still absent from the service and management UI.
- Budgets remain monthly-only, and warning logic does not honor the stored alert threshold.
- No Foundation Model parser layer exists.
- Siri shortcut coverage still lacks Open Transaction Entry and Check Spending.
- Default currency and automatic SMS parsing settings remain in-memory or are not consumed by runtime behavior.
- Accessibility/dynamic typography gaps from the original audit remain.
- Main-actor full-store fetch/filter/aggregation and the absence of an explicit SwiftData migration plan remain.

## Test and Evidence Assessment

- The repository still contains 14 test files and 126 declared test methods.
- Only `ExpenseManager/Tests/ExportTests/DataExportAndSecurityTests.swift` changed in the remediation commit.
- The only materially new behavioral assertion covers padded CSV formula input; most other test edits migrate old API calls.
- No new regression tests cover biometric fail-closed behavior, scene transitions, transfer/cash invariants, rollback failures, durable review acceptance, fingerprint races, account-last-four integration, SMS privacy persistence/export, multi-currency totals, restore failure, account balance history, App Intent precision, or speech runtime lifecycle.
- Some existing tests are weak: App Intent tests assert only non-nil results, and duplicate tests use mocks rather than concurrent SwiftData writes.
- There is no recorded BUILD → RUN → OBSERVE → VERIFY evidence.

**Evidence verdict:** UNVERIFIED. Test count is not proof of passing tests or of the claimed repaired behavior.

## Required Closure Order

1. Create a real iOS application/test target with plist, entitlements, resources, deployment settings, signing, and a reproducible Xcode build.
2. Make biometric protection fail closed and lock/redact on inactive transitions; correct `AppState` environment ownership.
3. Enforce transfer and cash-withdrawal invariants inside the domain service.
4. Redesign review items so pending records do not affect balances and acceptance state persists.
5. Make transaction, balance, fingerprint, and restore operations atomic and rollback-safe.
6. Define correct multi-currency presentation/aggregation behavior.
7. Add focused regression tests for every repaired defect, then run the full suite on macOS/iOS Simulator.
8. Store build, test, simulator, and privacy/device verification artifacts under `evidence/`; update `ISSUES.md` and `CHECKPOINT.md` from those artifacts rather than prose claims.

## Final Decision

**CHANGES REQUIRED / BLOCKING DEFECTS FOUND.**

Commit `472505a` is a substantial partial remediation, not complete closure. The project must remain blocked from production release until the open P0/P1 items are repaired and demonstrated through an actual Xcode build, full test execution, simulator/device checks, and durable Gauntlet evidence.
