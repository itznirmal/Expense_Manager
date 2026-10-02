# Brief implementation status

Updated: 2 October 2026. Scope authorized by the user: apply the brief, publish source and brief to GitHub, and prepare the next MacBook run. This pass evolves the existing iOS source rather than creating a second application.

The starting assessment used `6fda902`. The remote `cceb6e3` subsequently added splits, CSV import, widgets and other fixes. Both histories are preserved; those advanced features remain available as secondary flows. The audience decision is **everyday spending with optional budgets**.

## Implemented in source

| Brief requirement | Source result | Verification |
|---|---|---|
| Simple first use | Short currency/local-data welcome, skip or add first expense; no required account, budget or permissions. | First-use and navigation UI tests passed on the simulator. |
| Clear daily experience | Today / History / Plan; prominent Add expense; amount/category first, More details; analytics and Settings drill-downs. | Save/edit/relaunch and invalid-amount UI tests passed; broader rendered/accessibility checks remain. |
| Currency integrity | Selected-currency spending/budgets/analytics; ISO codes and fractional scales; ordinary postings reject mismatched accounts; changing preference does not relabel stored money. | Ledger, mixed-currency, formatting and account regressions. |
| Posting and refunds | Shared posted-state definition; separate gross expenses/refunds and net spending; pending/unaccepted records excluded. | Ledger and aggregate regressions. |
| Correct import identity | Bank and masked account hints retained; unique matching required; ambiguous SMS requires review; atomic transaction/fingerprint persistence. | SMS ambiguity/duplicate and ledger regressions. |
| Data recovery | Restore validates versions, unique IDs, enums, references, money precision and review state before mutation; rollback on failure; legacy checksum behavior retained. | Backup invalid-graph, roundtrip and legacy regressions. |
| Compatible budget schema | Historical V1 snapshot and V2 lightweight migration add currency with legacy INR backfill. | File-backed fixture migration regression; actual old-store upgrade pending. |
| Privacy and lock | Opaque inactive cover, financial overlays suppressed, background invalidates auth callbacks, lock settings fail closed; protected store/WAL/SHM and readable startup failure. | State tests and source review; physical-device behavior pending. |
| Optional advanced capture | Smart/voice save requires explicit confirmation; raw bank text not retained in notes; voice starts on tap and checks on-device capability. Shortcuts require device authentication and respect app-lock policy. | Boundary/voice/intent regressions; actual recording/Shortcuts pending. |
| Existing additions | Splits, CSV import, category management and widgets preserved. Currency-aware atomic CSV imports; widgets hide money by default and disable it with App Lock. | Split/import/backup source tests; real widgets/App Groups pending. |
| Portable verification | XcodeGen iOS 17 project, pinned macOS CI, shared simulator verification script, `.xcresult`/logs and MacBook guide. | Native build, 216 unit tests and 3 UI tests passed at fd05c8c. |

`Double` is used for chart coordinates, percentages and geometry after Decimal computations. Monetary persistence, validation and arithmetic use Decimal. Currency presets in pickers are suggestions; legacy/common ISO currencies remain valid. No FX conversion is introduced.

## Evidence and limits

This Windows workspace has no Swift/Xcode toolchain. Local checks can establish source consistency, conflict resolution, whitespace, file presence and project configuration; they cannot prove compilation, XCTest success, simulator UI behavior or security on a device. GitHub native run links/results belong in the latest checkpoint and `evidence/brief-implementation/` after they are observed.

The source assessment and original ratings remain historical. New source is not sufficient evidence to increase the release-readiness rating. Earlier claims of production readiness, build passing or “100% privacy” are superseded by this status. `QUALITY_BAR.md` stays frozen as the original acceptance reference; this file records the revised product scope and unresolved proof.

The issue ledger contains overlapping IDs inherited from two histories. New changes use `BRIEF-*` and distinguish simulator evidence from remaining device gates. Do not interpret an older `FIXED` row as device proof.

## Latest native result

[Run 36970787379](https://github.com/itznirmal/Expense_Manager/actions/runs/36970787379) **passed** at `fd05c8ca157bb2e267f3123d1e092e262aa6ce95`: all targets compiled, **216 unit tests and 3 UI tests passed with zero failures**. The run used macOS 15, Xcode 16.4 (16F6), the iPhone 16 Pro simulator and iOS simulator SDK 18.5. Its logs and `.xcresult` are retained in the run's `ios-verification-fd05c8ca157bb2e267f3123d1e092e262aa6ce95` artifact. Filtered results are in `evidence/brief-implementation/2026-10-02/native-run-36970787379.txt`.

The earlier `1311410` run compiled and passed its three UI tests but reported 55 failed assertions across 213 unit tests. The following patch corrected parser/ledger defects and fixture problems, then passed the new full run. Later documentation-only commits do not change the tested application or test code.

## Remaining work for Mac/device verification

Run [MacBook_Verification_Guide.md](MacBook_Verification_Guide.md) to establish your Mac's baseline, then observe the core flows at normal/large text sizes. Actual old-store migration, background snapshots, protected-data locking, biometric/Shortcuts policy, microphone teardown, cached widget privacy, share-sheet teardown and minimum iOS version remain acceptance gates. Disk-full/protected-data save-failure behavior also needs device evidence; an identifier-collision test establishes pre-mutation rejection, not an actual disk-save failure.

Startup retry preserves files; a confirmed backup recovery creates a separate store with iOS file protection configured and selects it only after successful restore. Physical protection remains a device gate. Refunds use the recorded refund date and reduce that period's category net spend. Remaining/pace is a recorded-spending estimate, not a bank balance or financial recommendation.

Confirmed recurring bills/reminders, receipt OCR, cloud sync, bank connections, sharing and monetization are deferred. The brief's proposed fresh single-currency ledger is adapted to the existing multi-currency data: separate visible summaries preserve old entries and require explicit currency selection. No historical monetary records are rewritten.

## Lessons from native integration

- Windows source scans did not establish a native build baseline. Pinned macOS/Xcode CI exposed actual SDK signatures and Swift 6 isolation failures before any tests could run.
- Keep SwiftData models on their owning actor. Services that cross actors return immutable Sendable values; do not mark persistence models unchecked Sendable to silence the compiler.
- Inject the actual observable app state and dependencies through typed SwiftUI environments. Default-value environments can accidentally substitute another container or state.
- Versioned SwiftData migrations need the SDK's real Schema instances and a file-backed upgrade fixture. A passing fixture still does not prove an existing user's development store will upgrade.
- XCTest UI operations require main-actor isolation. Keep setup within that isolation and preserve assertions for save, relaunch and correction rather than replacing failures with launch-only tests.
- A SwiftData unique attribute is not an instruction to reject an attempted create. Reject identifier collisions before inserting records or applying balances; validate both account legs before reversing an existing entry.
- A numeric regex can match the first three digits of a larger amount. Capture the complete Decimal token and let currency-scale validation reject unsupported precision. In classification, "credit card" describes a product; an explicit refund still takes precedence.
- Test fixtures must create their category relationships and choose empty mock ledgers explicitly. Demo transactions and absent categories can produce misleading assertions about totals or save counts.
- Preserve native logs and the tested revision alongside source findings. A later source fix is not passing evidence until a new native run succeeds.

## Final review scope

- **Standards — PASS for source/native compilation:** Decimal ledger arithmetic, observable main-actor UI state, typed environments, Sendable service values and Swift 6 strict-concurrency compilation. Rendered accessibility and device protection remain open.
- **Specification — PASS for this implementation pass:** everyday spending with optional budgets, three main destinations, fast manual entry, preserved records and secondary capture flows. First use, invalid amounts and save/relaunch/edit passed UI tests.
- **Adversarial invariants — PASS for the native regression suite:** amount precision, currency/account relationships, review-state exclusion, identity collisions, rejected updates, deduplication, graph validation, legacy backup handling and migration fixtures. Real I/O failures and OS authentication/privacy need device evidence.

**Verdict: APPROVED for source handoff and MacBook verification.** This review does not close the device release gates listed in the guide.
