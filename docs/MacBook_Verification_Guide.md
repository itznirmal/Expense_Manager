# Run and verify on a MacBook

This repository contains the iOS app. The audience is everyday spending with optional budgets. The product brief is [Expense_Tracker_iOS_Rebuild_Brief.md](Expense_Tracker_iOS_Rebuild_Brief.md); current implementation and evidence are tracked in [Brief_Implementation_Status.md](Brief_Implementation_Status.md).

## First run

Use Xcode 16.4 or newer with an installed iOS simulator runtime and XcodeGen. The deployment target is iOS 17. GitHub CI uses Xcode 16.4 on macOS 15. `project.yml` is the project source of truth. This is an iOS application; `swift test` on the Mac host does not replace simulator tests.

```bash
git clone https://github.com/itznirmal/Expense_Manager.git
cd Expense_Manager
brew install xcodegen
# If Xcode is not the selected developer directory:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
xcodebuild -runFirstLaunch
bash scripts/verify-ios.sh
open ExpenseManager.xcodeproj
```

Select the **ExpenseManager** scheme and an iPhone simulator, then Run. The script generates the project, discovers an installed compatible iPhone simulator, runs unit and UI tests, and saves its commit ID, build log, and `.xcresult` under `build/verification/`. To choose another simulator, set `IOS_SIMULATOR_ID` to its UDID from `xcrun simctl list devices available`. Keep results alongside the tested commit when handing off findings.

If Homebrew or Xcode is missing, install them before running the commands. If the script reports no simulator, install an iOS runtime in Xcode Settings. A newer Xcode can expose new compiler diagnostics; record its version rather than treating the pinned CI result as proof for that toolchain.

## On an iPhone

Set your development team in Xcode for **both** the app and widget extension. Enable App Groups for both and use the same registered identifier. The current value is `group.com.nirmal.ExpenseManager`; change the two entitlements and the app/widget snapshot constants together if your team requires another identifier. Ensure the bundle identifiers are available to your team. Simulator verification disables code signing; it does not prove device signing or App Group access.

Use a test install and synthetic financial entries for initial checks. Do not overwrite a ledger containing personal data merely to reproduce a test.

## Acceptance checks still requiring rendered or device evidence

| Scenario | Expected result |
|---|---|
| Fresh install | Currency choice, then an expense without signup, account, budget, voice, or automation setup. Today / History / Plan are the main tabs. |
| Core entry | Amount and category are prominent. More details are optional. Save, relaunch, edit and delete retain correct totals and balances. |
| Money | INR/USD/EUR summaries stay separate; JPY rejects fractions and KWD accepts three. Refund reduces net spending rather than increasing earned income. |
| Accounts | Expense/income/refund cannot post to another currency. A transfer uses distinct matching-currency accounts. Existing linked money cannot be relabeled through an account currency edit. |
| Optional budgets | The tracker works with no budget. Add/edit a monthly or category limit; remaining values and pace match the selected currency. |
| Imports | Review uncertain or ambiguous account hints. Repeating the same import does not add another entry. CSV preview retains its selected/declared currency; unsupported files produce an error. |
| Split | Child amounts equal the original exactly, account balance is unchanged, and backup/restore preserves the split. |
| Backup | Export → fresh test store restore preserves amounts, relationships, dates, review state and fingerprints. Corrupt checksum, missing relationships, unknown version and invalid precision fail before replacement. |
| App Lock | Enable/disable requires authentication. Cold launch and foreground return remain locked until success. Cancel/failure/unavailable authentication cannot disable the setting. Try a late callback after backgrounding. |
| Privacy cover | With and without App Lock, background/app-switcher snapshots, toasts, sheets, keyboard, export share sheets and nested sheets expose no financial content. Test Control Center and authentication transitions. |
| Protected files | Lock the physical device during a save/restore. The app handles protected-data availability without reset or data loss, then reopens after unlock. |
| Widgets | Amounts are hidden initially. Explicit opt-in shows the selected ledger. App Lock disables financial widget values. Check cached timelines after locking and revoking opt-in. |
| Voice | No recording before tapping. Permission denial and unsupported on-device recognition are clear. Dismissal/background stops recording; reduced motion suppresses pulsing. Verify offline operation. |
| Shortcuts | Device authentication is required. App Lock routes entry back inside the app. Test actual Shortcuts execution on the device; a unit call to `perform()` does not exercise OS authentication. |
| Accessibility | VoiceOver labels/order, large Dynamic Type at 320-point width, contrast, light/dark mode, reduced motion and 44-point controls. Record screenshots and issues. |

These checks are not claimed as passed merely because their test source exists. Minimum-version iOS 17 compatibility, physical authentication, app-switcher snapshots and file protection require their own proof even after CI passes on a newer simulator.

## Recovery without deleting records

If opening or migrating the store fails, the app preserves its files and offers Retry. Unlock the device and retry first. If the error persists, preserve the entire app container (including store, WAL and SHM) using Xcode's device tools before any replacement. Keep any earlier JSON backup separately. Investigate the failure on a copied test container. Do not uninstall or delete the original store as a migration fix.

The migration regression creates a historical V1 fixture and opens it as V2, adding INR to old budgets. It is not proof that every previously used unversioned or intermediate development store migrates. Test a copy of the actual old store. JSON backups include an unkeyed checksum; they are not encrypted or signed. The startup Restore a backup action validates the selected file, requests confirmation, and restores into a separate protected store. Original files remain untouched. A missing previously selected recovery store produces an error rather than silently selecting another ledger. Clearing the active ledger does not remove these preserved stores or exported backups.

## Instructions for the next agent

Read the brief, current status, AGENTS.md, QUALITY_BAR.md, ISSUES.md and latest CHECKPOINT.md entries. Run the verification script before changing code. Fix native failures and document their exact commands/results. Use the iOS developer/reviewer skills and the Gauntlet build/run/observe cycle. Keep historical issue IDs contextual: merged histories reused ISS-016 through ISS-024; new brief issues use `BRIEF-*` IDs.

Complete the core entry, ledger, migration, recovery and privacy gates before expanding advanced features. Retained voice, SMS, CSV import and widget source remains evidence-gated. Recurring bills, OCR, cloud sync, bank aggregation, sharing, paywalls and branding are outside this implementation pass.
