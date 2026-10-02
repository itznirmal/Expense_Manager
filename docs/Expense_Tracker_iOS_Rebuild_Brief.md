# Expense Tracker: Assessment, Lessons, and Fresh iOS Build Brief

Assessed: **2 October 2026**. Audience confirmed by the user: **everyday spending with optional budgets**.

**Implementation update:** The user subsequently authorized applying this brief and storing it in GitHub. The existing app has been updated with both local and newer remote work preserved. [Native run 36970787379](https://github.com/itznirmal/Expense_Manager/actions/runs/36970787379) passed at `fd05c8c`: 216 unit tests and 3 UI tests, zero failures. See [current implementation status and new native integration lessons](Brief_Implementation_Status.md) and [MacBook verification guide](MacBook_Verification_Guide.md) for the implemented scope and remaining device gates. Ratings, source counts and line references below describe the original assessment baseline, not the updated code or a release verdict.

This is a portable handoff for a future implementation agent. It preserves lessons from the current app while proposing a simpler product. The user explicitly permits deviation from the existing implementation. Product recommendations below began as proposals; the audience choice is confirmed. Read the current implementation status before starting so completed fixes and remaining verification work are carried forward.

## 1. Assessment basis and rating

The workspace already contains an iOS app, rather than a non-iOS tracker to port. The source baseline is commit `6fda90203cc7fd7b8982c23ad8bb8944ae8cc86d` on `main`. The initial working tree was clean. The assessment covers source, tests, prior audit/remediation records, and current official market/platform documentation. It does not assess an Android version or a running iPhone app.

**Provisional overall rating: 6/10 as an implementation prototype. Product potential: 8/10. Release readiness: 3/10.** These are reviewer judgments, not user-study scores or App Store ratings. A useful app with material gaps scores around 6; a reliable product demonstrated on devices would need to earn 8 or above.

| Dimension | Score | Reason |
|---|---:|---|
| Feature coverage | 7/10 | Broad capture, accounts, budgets, search, analytics, and export foundations. Some advertised flows remain partial. |
| Engineering foundations | 7/10 | Decimal models, shared candidates, service seams, schema versioning, and focused ledger regressions are worthwhile foundations. |
| Everyday simplicity | 5/10 | Automation and finance breadth dominate; first-use guidance and a clear default capture journey need more attention. Source-derived assessment only. |
| Trust and recovery | 5/10 | Local storage, review state, duplicate safeguards, and sanitized export help; privacy guarantees and restore invariants need stronger verification. |
| Demonstrated release readiness | 3/10 | No current build, test-run, or rendered-device evidence was available to establish readiness. |

The overall score is a qualitative synthesis, not an arithmetic average. Source inspection can identify broken wiring and missing flows, but cannot establish visual polish, recording latency, entry speed, accessibility usability, or actual privacy behavior.

**Original assessment evidence boundary:** this Windows host had no `swift`, `xcodebuild`, or `xcrun` on PATH. There were 21 unit-test source files and two UI-test methods. The pre-existing `evidence/` inventory contained four static verification text files, with no simulator screenshots or `.xcresult` artifacts. Tests existing in source were not tests passing. CI configuration existed; its latest run was not checked at that point. See [assessment basis](../evidence/product-assessment/2026-10-02/assessment-basis.txt). Current native results are linked in the implementation update above.

Older README/release documents claim verified production readiness. Later checkpoint entries explicitly require macOS/Xcode verification, and `ISSUES.md` still contains open ISS-020. Treat the earlier readiness claims as superseded evidence, not a release verdict. The old plan targets iOS 26+, while `Package.swift` targets iOS 17; a fresh build must choose and document one core baseline.

## 2. What the current implementation contributes

| Area | Source-supported state | Value for a rebuild |
|---|---|---|
| Capture | Manual, smart-text, voice, Siri/App Intents, and bank-message ingestion code exists. | Keep fast entry and shared normalization; add channels only after the core is reliable. |
| Ledger | Accounts, categories, transaction CRUD, transfer/cash paths, accepted/review state, Decimal amounts. | Preserve accounting invariants and regression scenarios. |
| Imports | SMS safety classifier, bank templates, fingerprints, confidence tiers, and review queue. | Keep staged review, rejection of non-transactions, and atomic deduplication. |
| Spending | Dashboard, category/merchant summaries, Swift Charts, monthly/category budget calculations. | Keep useful answers; simplify navigation and terminology. |
| Recurrence | Historical merchant-pattern detection exists. | Distinguish a possible recurring charge from a confirmed future bill. |
| Data ownership | CSV, versioned JSON backup/restore, app lock, privacy settings. | Treat reliable recovery and export as core product features. |
| Later-plan features | Receipt/screenshot OCR, widgets, notifications, shared finances, and model fallback are not established as completed by this assessment. | Do not inherit the old plan's entire scope into V1. |

Principal source areas: `ExpenseManager/Features/`, `ExpenseManager/Core/Storage/`, `ExpenseManager/Core/Parsing/`, `ExpenseManager/Core/SMSParsing/`, `ExpenseManager/Core/Export/`, and `ExpenseManager/Tests/`. The previous 26-phase master plan is historical design input, not the new scope contract.

## 3. Findings that should change the next build

These are selected current source findings, rather than an exhaustive security audit. P1 means incorrect financial behavior or a significant privacy/workflow risk. Runtime triggers have not been exercised on this host.

| Finding | Current evidence | Requirement for the rebuild |
|---|---|---|
| **P1: Ordinary expenses can debit an account in another currency.** | Relationship validation checks transfer/cash currencies but does nothing for expense/income/refund at `Core/Storage/SwiftDataTransactionService.swift:320-355`; insertion applies the amount at `:437-475`. | Reject currency mismatch for every posting kind, before any mutation. |
| **P1: Some summaries mix currencies; others hide them.** | Budgets aggregate all expenses into a currency-less budget (`Core/Storage/SwiftDataBudgetService.swift:35-58`); analytics aggregates fetched transactions without currency partitioning (`Features/Analytics/AnalyticsViewModel.swift:141-274`). Dashboard exposes only its default currency. | One explicit ledger currency in V1, or fully partitioned visible summaries; no hidden or blended money. |
| **P1: Unaccepted records can enter posted reports.** | Reads/totals exclude pending records but not all `isAccepted == false` records (`Core/Storage/SwiftDataTransactionService.swift:57-101,296-315`); CSV follows the same pattern (`Core/Export/DataExportService.swift:38-43`). Balance reversal uses a stricter posted condition. | One posting-state definition reused by balances, history, budgets, charts, and export. |
| **P1: Parsed account identity is lost before ledger resolution.** | The SMS parser extracts account mask and bank, but ingestion forwards only the bank name (`Core/SMSParsing/SMSIngestionOrchestrator.swift:59-73,195-212`). Service last-four matching exists but cannot use a missing mask (`Core/Storage/SwiftDataTransactionService.swift:562-590`). | Preserve bank/masked-account hints separately; resolve a stable account ID or require review. Test differently named and multiple same-bank accounts. |
| **P1: Financial toasts can remain above the lock screen.** | Lock shield uses zIndex 200; toast uses 300 and remains rendered (`Features/Root/RootView.swift:22-41`). Entry/review success messages contain amount/merchant (`Features/ManualEntry/ManualTransactionComposerViewModel.swift:252-255`, `Features/ReviewQueue/ReviewQueueViewModel.swift:82-85`). | Suppress sensitive overlays and sheets while locked; verify app-switcher snapshots and scene transitions on devices. |
| **Recovery gap: Restore can silently lose relationships.** | Validation checks only a limited structure and checksum (`Core/Export/DataExportService.swift:248-270`); unresolved account/category references become nil during restore (`:337-360`). | Reject an inconsistent graph before replacement; report errors without destroying the existing ledger. |
| **Privacy gap: On-device speech support is not checked.** | `Core/Voice/AudioRecordingService.swift:111,140` requests local recognition without testing the support property. | Capability-gate voice and prove the no-network behavior; see the Apple source in lesson 9. |
| **State wiring risk: The app injects one environment mechanism and reads another.** | `App/ExpenseManagerApp.swift:26` uses type-based `.environment(appState)`, while `Features/Root/RootView.swift:12` reads the custom key whose default creates another instance (`App/AppState.swift:207-215`). | Use one state instance and one consistent injection/read mechanism; verify lock, navigation, sheets, and counts through the live app. |
| **Evidence gap: Current UI tests can pass without exercising required controls.** | `ExpenseManagerUITests/ExpenseManagerUITests.swift:36-78` conditionally taps controls only when they exist. Launch flags do not establish an isolated store in the app entry point. | Assert required controls, seed a dedicated test store, and verify save/relaunch/edit outcomes. |

Source paths in this table are relative to `ExpenseManager/`, except the explicit UI-test path. Selected parent-reviewed excerpts are saved in [source observations](../evidence/product-assessment/2026-10-02/source-observations.txt). Some findings extend beyond the prior ledger; this assessment does not mark them fixed or change that ledger's historical statuses.

The product audit also found a direct launch into five tabs without a first-use currency/privacy/capture path (`App/ExpenseManagerApp.swift:13-33`), a dashboard containing many competing sections (`Features/Dashboard/DashboardView.swift:20-74,249-289`), and a review badge initialized to zero and refreshed only after review actions (`App/AppState.swift:91`, `Features/ReviewQueue/ReviewQueueViewModel.swift:79,108`). Hydrate pending state from storage on launch. Manual entry has useful autofocus/defaults; improve its progressive disclosure rather than copying all visible fields into the new default composer. Fixed monetary typography (`Core/DesignSystem/Typography.swift:18-27`) also needs actual accessibility-size verification. The UI test's expected launch title is "Expense Manager," while the dashboard title is "Dashboard"; correct the test contract before treating it as validation.

## 4. Market comparison and useful borrowing

Official sources checked on 2 October 2026. **Competitor capabilities below are vendor claims**, not hands-on observations. Availability, prices, supported banks, and features vary by region and plan; no current subscription-price or App Store rating comparison is asserted. The question is which patterns suit this audience, not which app wins universally.

| Reference | Claimed strength | What to borrow | Fit/tradeoff |
|---|---|---|---|
| **Dime** | Manual tracking, category budgets, recurring expenses, widgets, Siri Shortcuts, export and biometric lock. | Native quick capture and lightweight optional planning. | Closest product archetype for this audience. Visible version history ends at 2.1.3 in November 2023; current maintenance and its developer-provided privacy claims need independent checks. iCloud sync is a separate data-flow choice. [App Store listing](https://apps.apple.com/us/app/dime-budget-expense-tracker/id1635280255). |
| **Monarch Money** | Flex/category budgeting, rollovers, recurring-bill planning, manual entries, and household features. | Simple flexible-spend view, optional category limits, and visible upcoming obligations. | Useful planning reference; hosted household finance is broader than this V1. Reviewed official material limits mobile availability to US/Canada. [Budget design](https://help.monarch.com/hc/en-us/articles/360048883631-Creating-Your-Budget-in-Monarch), [availability](https://www.monarch.com/download), [recurring items](https://www.monarch.com/features/recurring). |
| **Copilot Money** | Automated categorization, spend-based budgets that can be disabled, rollovers, recurrence, widgets, CSV export. | A useful spending experience with budgets turned off; clear recurring-charge views and glanceable summaries. | Reviewed FAQ says US-only; aggregation and hosted financial data do not suit the proposed local-first core. [Budget toggle](https://help.copilot.money/en/articles/11157550-quick-start-guide), [availability/model](https://www.copilot.money/faq), [widgets](https://help.copilot.money/en/articles/9834331-adding-widgets), [export](https://help.copilot.money/en/articles/5944414-exporting-your-transaction-data). |
| **YNAB** | Allocation-based budgeting, targets, scheduled entries, mobile quick entry, widgets and Shortcuts. | Repeat-entry convenience, explicit planned-versus-posted transactions, and reconciliation discipline. | Powerful for intentional budgeting; mandatory allocation would add friction to a spending-first app. Bank import has regional/provider limits. [Method](https://www.ynab.com/the-four-rules/), [mobile entry](https://support.ynab.com/en_us/how-to-add-transactions-in-ynab-HyDwA_byi?mobile-help=true), [direct import](https://support.ynab.com/en_us/how-direct-import-works-H1IGYLgnxl). |
| **MoneyWiz** | Manual accounts, scheduled bills/forecast calendar, file imports, multiple budget methods, reports and exports. | Reliable file ownership and scheduled planning. | Breadth would overwhelm a lightweight V1. Local/offline and optional-sync descriptions are vendor claims; the reviewed privacy policy is dated January 2021. [App Store listing](https://apps.apple.com/us/app/moneywiz-2026-personal-finance/id1511185140), [privacy/storage policy](https://www.wiz.money/support/privacy-policy). |
| **Spendee** | Wallets, single-screen entry, labels, category budgets, recurring transactions, shared wallets and multi-currency features. | Easy entry and approachable category organization. | Cloud/sharing/bank features add cost and privacy tradeoffs. Its App Store label declares linked financial/usage data; mobile export and sharing have restrictions. [App Store listing](https://apps.apple.com/us/app/expense-budget-app-spendee/id635861140), [export limits](https://help.spendee.com/article/137-export-transactions), [shared-wallet limits](https://help.spendee.com/article/224-shared-wallets). |

**Priority judgment:** adopt fast manual capture, optional budget limits, transparent correction/review, and data ownership in V1. Add confirmed recurring plans and quick-add OS surfaces next. Defer bank sync, household collaboration, OCR, complex FX, and investment/net-worth features. This deliberately narrows the market feature set to protect speed and trust.

Borrow the problem-solving pattern, not another app's branding, copy, icons, or distinctive layout. A feature is worth adopting only if it makes everyday capture, understanding, or recovery easier without compromising the product's privacy promise.

## 5. Lessons already learned in this implementation

1. **A corrected ledger is more valuable than another entry channel.** Prior remediation addressed accepted versus pending records, reversing old effects on edit/delete, missing transfer accounts, and currency mismatches. Validate the complete replacement before reversing an accepted transaction. Pending/unaccepted records must have no balance or spending effect. Preserve the ISS-017 scenarios as external-behavior tests.
2. **Import record and fingerprint belong to one commit.** ISS-019 introduced paired persistence and rollback with an explicit saved/duplicate outcome. Include account identity in deduplication. Exact re-import must be a no-op; similar legitimate purchases must not be silently erased by a coarse time window.
3. **Backups include workflow state.** ISS-018 added pending, accepted, and review-reason preservation and a frozen legacy wire fixture. Include fingerprints, relationships, rules, and user preferences that change behavior. Restoring a pending import must not turn it into posted spending.
4. **Validate before destructive restore, and validate more than a checksum.** Payload versions, required fields, IDs, references, monetary ranges, and balance invariants matter. An unkeyed SHA-256 checksum detects corruption; it is neither encryption nor proof that an attacker has not edited and rehashed a file. Never describe a checksum as a cryptographic signature. Restores must preserve the old store on any failure.
5. **Decimal precision begins at the boundary.** The current ledger uses Decimal, but `LogExpenseIntent.swift:21,63` receives a Double before converting it. A later conversion cannot recover precision already lost. Prefer validated decimal text at integration boundaries; reject non-finite values and apply explicit currency scale/rounding rules.
6. **Currency safety includes visibility.** Grouping correctly but hiding other currencies still misleads users. The current default is fixed to INR/en_IN (`CurrencyFormatter.swift:18-19`). Store currency separately from display locale. Never sum different currencies without an explicit conversion policy, rate, and timestamp.
7. **Parsing suggests; deterministic code accounts.** All entry adapters should create a normalized candidate. Amount, currency, account, date, and direction are critical fields. Confidence is a heuristic until calibrated against a labeled corpus; a high score is not proof of accuracy. Require review for critical ambiguity. Never ask an LLM to calculate balances or totals.
8. **Bank messages are sensitive input, not transaction notes.** Retain sanitized metadata and fingerprints; do not keep raw messages, audio, or screenshots by default. Reject OTPs, failed/declined payments, balance-only alerts, and promotions before transaction generation. Test rejection across every relevant input adapter, not only the SMS screen.
9. **Privacy claims require capability checks and device evidence.** `AudioRecordingService.swift:111,140` checks availability and requests on-device recognition, but does not check `supportsOnDeviceRecognition`. Apple documents that the flag is honored only when that support exists. For the rebuild, disable unsupported voice capture and offer manual entry; do not silently enable network recognition. Actual network behavior remains unverified here. [Apple speech support](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition).
10. **Platform automation needs an early real-device proof.** Keep message imports user-configured through Shortcuts, rather than assuming inbox access. Apple's filtering extension is restricted to particular messages and cannot write shared app containers; it is not a general ledger-import workaround. Shortcuts supports message triggers, but individual actions and locked-device execution need testing on each supported OS. [Apple communication triggers](https://support.apple.com/en-ae/guide/shortcuts/apdd711f9dff/ios), [Apple automation execution](https://support.apple.com/guide/shortcuts/add-automations-apdfbdbd7123/ios), [Apple message-filter limitations](https://developer.apple.com/documentation/identitylookup/sms-and-mms-message-filtering).
11. **Static completion is not release completion.** ISS-016 through ISS-019 have source repairs and regression code, but their local evidence explicitly excludes Swift/XCTest execution. Do not re-report them as runtime-verified fixes. Freeze measurable acceptance criteria, retain an issue ledger, and attach real build/test/device evidence to closures.
12. **Polish is behavior as well as styling.** Prioritize clean first use, inline validation, editable suggestions, understandable errors, safe cancellation, and recovery. Replace product copy such as internal `AC-SEC-1` identifiers with plain explanations. Verify Dynamic Type, VoiceOver, contrast, tap targets, and reduced motion on real rendered screens.

Historical regression references: `ExpenseManager/Tests/FinancialEngineTests/TransactionLedgerInvariantTests.swift`, `ExpenseManager/Tests/ExportTests/DataExportAndSecurityTests.swift`, `ExpenseManager/Tests/SMSParsingTests/DuplicatePreventionTests.swift`, and the four static evidence files. Reuse the expected behaviors and fixtures; review code before reusing it.

## 6. Recommended fresh product

**Promise: Record spending quickly, understand where it went, and optionally set a limit.** Budgets should add value when chosen; skipping them must leave a complete useful tracker.

Suggested navigation: **Today**, **History**, and **Plan**, with Settings accessible from the toolbar and one consistent **Add expense** action. Today shows this month's recorded spending, a short category breakdown, and recent entries. Show an optional budget card only when a limit exists. Put deeper charts in a drill-down rather than a separate competing top-level destination. Plan contains optional budgets and, later, confirmed recurring items.

Default capture: amount and category first; merchant/note, account, date, and type are available progressively. Use remembered choices with easy correction. Smart text is an alternate capture mode, not a prerequisite. Every save gives feedback and a clear way to correct the entry. Do not require an account signup, bank connection, microphone permission, budget setup, or automation setup before the first saved expense.

V1 smart-text input always produces an editable preview and requires an explicit Save. Voice, if added later, starts only after an explicit tap and a clear permission explanation. A short pause in speech must not become permission to post a financial transaction.

### V1 scope and user stories

| Priority | User need | Proposed behavior |
|---|---|---|
| Essential | Start immediately | Confirm a currency, then save an expense; optional short explanation of local data and backup. |
| Essential | Capture everyday spending | Fast amount/category composer, optional merchant/note/account/date, income/refund/transfer when needed. |
| Essential | Correct mistakes | Edit/delete with correct totals and balances; confirmation or undo for destructive actions. |
| Essential | Understand spending | Monthly total, category breakdown, date comparison, searchable/filterable history; clear empty states. |
| Essential | Own and recover data | Sanitized CSV export, versioned backup/restore, lock, clear deletion confirmation, store-open recovery. CSV import is deferred. |
| V1, optional to use | Set a limit | Ship one monthly spending limit, disabled until chosen; remaining amount and clearly labeled pace estimate. Category limits can follow. |
| Optional V1 | Reduce repetitive entry | Local merchant/category memory with user control; smart-text candidate preview if it meets accuracy gates. |
| Next | Plan repeat bills | User-confirmed recurring schedule and optional local reminder; expected items separate from posted entries. |
| Next | Capture outside the app | Quick-add widget and App Shortcut through the same validation/save operation; hide financial widget values by default. |
| Later, evidence-gated | Voice, SMS/Wallet automation, OCR, CSV import | Add independently after hardware/OS and reliability proofs, with preview and duplicate handling. |

### Deliberately deferred

Mandatory zero-based budgeting, investment/net-worth dashboards, bank aggregation, shared household sync, financial advice chat, predictive AI, complex FX, and subscription detection presented as fact. Branding and monetization remain open. Do not add a backend or cloud processing as infrastructure for hypothetical future features.

Recurring planning is a better next step than adding more charts, but it must not hold up a reliable spending tracker. Optional iCloud sync can be researched later; it changes the data-flow promise and needs conflict, deletion, backup, and disclosure design before adoption.

## 7. Financial and data contract for the new app

- Use positive validated Decimal magnitudes with an explicit transaction kind, currency code, and posting state. Define supported currencies' fractional precision; reject invalid input with a correction message rather than silently taking `abs(amount)` or clamping. Balances may be negative according to account type.
- Recommended V1 simplification: one chosen currency per ledger. Reject or stage a foreign-currency import with a visible explanation. Do not display it as zero or silently omit it. Changing display locale must not alter currency or historical amounts. Changing ledger currency must not relabel existing money.
- If accounts are included, keep them optional for ordinary expenses. Transfers require distinct, valid source/destination accounts in the ledger currency. Expense reduces source balance; income/refund increases it; transfer/cash withdrawal moves value without creating spending/income. Credit-card payment is a transfer, not a second expense.
- Define gross expense and refunds separately, then label net spending explicitly. The default report attributes each posted event to its recorded transaction date; a refund received this month affects this month's net spending. Scheduled future bills and pending review imports do not affect posted totals.
- Derive balances from opening balance and accepted ledger effects, or maintain cached balances only inside the same atomic persistence operation and verify them against the ledger. Opening-balance edits require an explicit adjustment policy. Account/category deletion must not orphan or destroy history by surprise.
- Date-only expenses use a documented calendar-day policy. Monthly filtering uses a half-open interval from month start to next month start. Test leap years, timezones, DST, and year boundaries.
- Remaining budget equals limit minus posted net spending for its period. Daily pace is an estimate based on recorded data, not a guarantee of money available to spend. Do not call it safe-to-spend without accounting for obligations, reserves, and data completeness.
- Backup restoration validates graph integrity and consistency before replacing live data. Keep a recoverable pre-restore snapshot and test forced failures. Legacy formats use explicit migration rules and fixed fixtures. Offer an encrypted-backup option only with a specified key/recovery model; do not imply that plain JSON is private after sharing.
- CSV export neutralizes formula-triggering **text** prefixes (`=`, `+`, `-`, `@`, tab/carriage return, including leading padding), with proper quoting for commas/quotes/newlines. Keep legitimate signed numeric fields numeric. Test these separately rather than indiscriminately prefixing every negative number.

Concrete regression fixtures for the next implementation:

| Scenario | Explicit expected behavior |
|---|---|
| Decimal boundary | `0.10 + 0.20 == 0.30` exactly; currency-specific fractional input is either valid or visibly rejected according to the declared policy. |
| Posted ledger | Starting from zero, income 1000, expense 200, transfer 100 from A to B yields A=700, B=100, net spending=200. Refund 50 into A yields A=750, B=100, net spending=150. |
| Review/duplicate | A pending expense 25 changes neither balances nor posted spending; acceptance changes them once. Re-importing the exact event changes neither record count nor balance. |
| Invalid replacement | Editing a posted transfer to use the same account or another currency fails; its old fields and both old balances remain unchanged. Ordinary expense currency mismatch also fails. |
| Restore/lock | A backup with a missing referenced account is rejected and the old store survives. Backgrounding during an amount-bearing success toast reveals no financial content in the locked UI/snapshot. |

## 8. Minimal architecture and platform policy

Prefer one native application target with four cohesive logical areas, rather than many packages:

| Area | Owns | Boundary to verify |
|---|---|---|
| Ledger and Storage | Money rules, transactions, accounts, schema/migrations, atomic save/restore | Public create/update/delete/import operations and persisted results |
| Capture | Manual/smart adapters, parsing, review, duplicate decisions | Input to candidate; candidate to reviewed/posted outcome |
| Spending and Planning | Queries, summaries, optional budgets, future recurrence | Fixed ledger fixtures to explicit displayed numbers |
| App Experience and Privacy | Navigation, settings, lock, exports, accessibility, OS entry surfaces | End-to-end journeys, lifecycle lock, export/recovery results |

Use SwiftUI, Observation (`@Observable`), `@MainActor` UI state, SwiftData with an explicit migration plan, Swift Charts when useful, and Apple frameworks for security/OS integration. Introduce protocols at real persistence or platform boundaries. Keep financial calculations out of Views. Avoid speculative repositories, duplicate pipelines, global mutable state, and unchecked concurrency annotations used to silence diagnostics.

Core minimum OS recommendation: iOS 17+ if current distribution/toolchain requirements permit it. Confirm this at build kickoff. Compile with a pinned, compatible Xcode/Swift toolchain and an available simulator destination. V1 smart text uses deterministic parsing and local rules; Foundation Models is deferred and must not drive V1 architecture. If later introduced, availability-check it and select the on-device model explicitly; newer documentation also describes server-backed options. [Apple model availability](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models), [Foundation Models overview](https://developer.apple.com/documentation/FoundationModels).

**Proposed V1 privacy policy:** require device unlock for external quick-add and app authentication when App Lock is enabled. No locked background writes in V1. Keep widget amounts hidden by default. App Lock must cover sensitive sheets, toasts, background snapshots, cold launch, and interrupted authentication. Test every entry surface against the same rule. A later explicitly opted-in write-only automation would be a separate privacy/storage decision.

Use iOS complete file protection for the foreground-only ledger store, sidecars, and temporary exports; verify file attributes and protected-data lifecycle handling with the chosen SwiftData setup before release. This uses OS protection, not a claim of an additional application-encrypted database. Handle unavailable protected data as a recoverable locked state, never by creating an empty replacement store. Shared CSV/plain-JSON destinations do not inherit the application's protection guarantee. [Apple file protection and lifecycle guidance](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files).

## 9. Build order and observable acceptance gates

These are **proposed acceptance criteria for a new project**, not edits to the existing frozen `QUALITY_BAR.md`.

| Slice | Build | Required proof before expanding |
|---|---|---|
| 0 | Choose supported OS/Xcode, generate native app/test targets, establish evidence protocol | Clean build and an isolated test database on macOS; app launches on minimum and current supported OS. |
| 1 | Ledger + manual capture + History | Save, relaunch, edit, delete, refund, transfer, pending/no-posting, rejected update, currency and Decimal boundary tests; totals and balances remain exact. |
| 2 | Today + optional budget + accessible first use | First saved expense in at most three app screens without account/signup/budget setup. Record repeated-entry timing; target median <=5 seconds for a familiar user, never claim speed without measurement. |
| 3 | Data ownership + privacy + recovery | Backup round trip, legacy restore, malformed graph, save-failure rollback, CSV safety, cold/background lock, no private-data logging, store-open recovery. |
| 4 | Local smart capture + corrections | At least 100 labeled cases across supported grammar/locale and rejection/duplicate inputs; target >=95% exact critical-field matches on supported transaction cases, with reported failures. Zero posting without explicit Save; all labeled OTP/failed/balance-only/promotional cases rejected. |
| 5 | Select one next feature: recurring planning or quick-add surfaces | Complete user journey through the existing ledger operation; recurrence cannot double-count expected and actual spending, widget/intent cannot bypass money or lock policy. |

Across slices, verify empty and populated data, compact iPhone and larger layouts, Light/Dark mode, maximum accessibility text, VoiceOver, reduced motion, and airplane mode. Use an isolated seeded UI-test store with required controls asserted to exist; never allow a missing button to make a test silently skip the journey. Exercise save/edit/relaunch behavior, not just navigation titles.

Define the three-screen first-save journey as currency/privacy introduction -> expense composer -> saved Today/History result; a permission prompt must not be required. For the <=5-second repeated-entry target, record device/OS/build, use the same seeded category set, give two practice attempts, then measure ten ordinary expense saves from tapping Add to visible persisted confirmation; report the median and all failures. For store-open recovery, simulate a container-open/migration failure: show a readable recovery screen, leave the original files untouched, offer retry or validated backup restore, and never silently reset the ledger. Test file protection while locked, after first unlock, and after relaunch on a physical device.

For the future build, freeze `QUALITY_BAR.md`, maintain `ISSUES.md` and append-only `CHECKPOINT.md`, and run BUILD -> RUN -> OBSERVE -> CRITIQUE -> FIX -> VERIFY. Use bounded Luna workers with non-overlapping ownership for implementation slices and read-only investigators for evidence gathering. The parent agent owns architecture, difficult debugging, three-axis review, integration, and final verification. Write regression tests for correctness/privacy defects before fixing them. Store build logs, `.xcresult`, screenshots, and device observations with the exact revision and toolchain. Do not replace absent runtime evidence with static assertions.

## 10. Ready-to-use instruction for the next agent

> Create a fresh native iOS expense tracker using this brief. The confirmed audience is everyday spending with optional budgets. The existing Expense Manager is a reference for lessons and regression scenarios, not a required design or codebase to copy. Start with Slice 0, then deliver a complete manual-capture/ledger/History slice before adding automation. Preserve Decimal precision, atomic ledger changes, pending-versus-posted semantics, duplicate protection, local storage, sanitized exports, and recoverable backup/restore. Use the four logical ownership areas above, modern SwiftUI/Observation/SwiftData, and small vertical slices. Verify on macOS/Xcode and actual rendered iOS screens. Keep build/test/runtime evidence distinct. If execution is unavailable, state that clearly and retain the runtime gate. Review copied source against the findings in this file. Do not mark the app release-ready from static analysis. Treat branding, pricing, cloud sync, and bank integration as later decisions. Read the new workspace's AGENTS.md and applicable iOS developer/reviewer/Gauntlet skills before implementation.

Open decisions at kickoff: final product name; supported core OS/toolchain; supported currency list; backup encryption/recovery design; distribution and monetization. None should require delaying source analysis or a reversible core prototype, but settle privacy/backup behavior before a public release.
