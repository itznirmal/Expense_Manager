# Brief implementation status

Updated: 2 October 2026. Scope authorized by the user: apply the brief, publish source and brief to GitHub, and prepare the next MacBook run. This pass evolves the existing iOS source rather than creating a second application.

The starting assessment used `6fda902`. The remote `cceb6e3` subsequently added splits, CSV import, widgets and other fixes. Both histories are preserved; those advanced features remain available as secondary flows. The audience decision is **everyday spending with optional budgets**.

## Implemented in source

| Brief requirement | Source result | Verification |
|---|---|---|
| Simple first use | Short currency/local-data welcome, skip or add first expense; no required account, budget or permissions. | UI tests assert first-use navigation; rendered run pending. |
| Clear daily experience | Today / History / Plan; prominent Add expense; amount/category first, More details; analytics and Settings drill-downs. | Typed environment wiring scanned; save/edit/relaunch UI regressions added. |
| Currency integrity | Selected-currency spending/budgets/analytics; ISO codes and fractional scales; ordinary postings reject mismatched accounts; changing preference does not relabel stored money. | Ledger, mixed-currency, formatting and account regressions. |
| Posting and refunds | Shared posted-state definition; separate gross expenses/refunds and net spending; pending/unaccepted records excluded. | Ledger and aggregate regressions. |
| Correct import identity | Bank and masked account hints retained; unique matching required; ambiguous SMS requires review; atomic transaction/fingerprint persistence. | SMS ambiguity/duplicate and ledger regressions. |
| Data recovery | Restore validates versions, unique IDs, enums, references, money precision and review state before mutation; rollback on failure; legacy checksum behavior retained. | Backup invalid-graph, roundtrip and legacy regressions. |
| Compatible budget schema | Historical V1 snapshot and V2 lightweight migration add currency with legacy INR backfill. | File-backed fixture migration regression; actual old-store upgrade pending. |
| Privacy and lock | Opaque inactive cover, financial overlays suppressed, background invalidates auth callbacks, lock settings fail closed; protected store/WAL/SHM and readable startup failure. | State tests and source review; physical-device behavior pending. |
| Optional advanced capture | Smart/voice save requires explicit confirmation; raw bank text not retained in notes; voice starts on tap and checks on-device capability. Shortcuts require device authentication and respect app-lock policy. | Boundary/voice/intent regressions; actual recording/Shortcuts pending. |
| Existing additions | Splits, CSV import, category management and widgets preserved. Currency-aware atomic CSV imports; widgets hide money by default and disable it with App Lock. | Split/import/backup source tests; real widgets/App Groups pending. |
| Portable verification | XcodeGen iOS 17 project, pinned macOS CI, shared simulator verification script, `.xcresult`/logs and MacBook guide. | Windows static checks; native result recorded separately. |

`Double` is used for chart coordinates, percentages and geometry after Decimal computations. Monetary persistence, validation and arithmetic use Decimal. Currency presets in pickers are suggestions; legacy/common ISO currencies remain valid. No FX conversion is introduced.

## Evidence and limits

This Windows workspace has no Swift/Xcode toolchain. Local checks can establish source consistency, conflict resolution, whitespace, file presence and project configuration; they cannot prove compilation, XCTest success, simulator UI behavior or security on a device. GitHub native run links/results belong in the latest checkpoint and `evidence/brief-implementation/` after they are observed.

The source assessment and original ratings remain historical. New source is not sufficient evidence to increase the release-readiness rating. Earlier claims of production readiness, build passing or “100% privacy” are superseded by this status. `QUALITY_BAR.md` stays frozen as the original acceptance reference; this file records the revised product scope and unresolved proof.

The issue ledger contains overlapping IDs inherited from two histories. New changes are recorded as `BRIEF-*`, with **IMPLEMENTED / NATIVE PENDING** until execution supplies evidence. Do not interpret an older `FIXED` row as device proof.

## Remaining work for Mac/device verification

Run [MacBook_Verification_Guide.md](MacBook_Verification_Guide.md), resolve native diagnostics and failed regressions, then observe the core flows at normal/large text sizes. Actual old-store migration, background snapshots, protected-data locking, biometric/Shortcuts policy, microphone teardown, cached widget privacy, share-sheet teardown and minimum iOS version remain acceptance gates.

Startup retry preserves files; a confirmed backup recovery creates a separate protected store and selects it only after successful restore. Refunds use the recorded refund date and reduce that period's category net spend. Remaining/pace is a recorded-spending estimate, not a bank balance or financial recommendation.

Confirmed recurring bills/reminders, receipt OCR, cloud sync, bank connections, sharing and monetization are deferred. The brief's proposed fresh single-currency ledger is adapted to the existing multi-currency data: separate visible summaries preserve old entries and require explicit currency selection. No historical monetary records are rewritten.
