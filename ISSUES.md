# Issues Ledger (Gauntlet Protocol)

| ID | Sev | Component | Observed | Evidence | AC | Status | Fix Details |
|---|---|---|---|---|---|---|---|
| ISS-001 | P1 | SwiftDataAccountService | Credit Card net worth subtraction inverted on negative balance | Review Report 4abf473d | AC-FIN-1 | FIXED | Standardized sum of balances across accounts |
| ISS-002 | P1 | SwiftDataTransactionService | Negative transaction amount reverses accounting balance adjustment | Review Report 4abf473d | AC-FIN-1 | FIXED | Normalized candidate amount using abs(amount) |
| ISS-003 | P2 | FinancialEngineTests | Missing test coverage for Credit Card Net Worth with transactions | Review Report 4abf473d | AC-FIN-1 | FIXED | Added credit card expense/payment & negative amount test cases |
| ISS-004 | P0 | Manifest / Repo Root | Missing Package.swift build manifest and Info.plist | REVIEW_REPORT.md Cluster 1 | AC-ARCH-1 | FIXED | Created Swift 6.0 Package.swift and Info.plist with Face ID/Speech permissions |
| ISS-005 | P0 | LogExpenseIntent / ParseTextExpenseIntent | Outdated entity creation and unhandled Double conversion | REVIEW_REPORT.md Cluster 2 | AC-ARCH-2 | FIXED | Migrated to SwiftDataTransactionService, exact Decimal conversion, and error handling |
| ISS-006 | P0 | SMS Parsing / Orchestrator | Property mismatch on accountLastFour and raw SMS in notes | REVIEW_REPORT.md Cluster 2 | AC-PARSE-1 / GT-69 | FIXED | Reconciled accountLastFour alias and enforced notes: nil for raw bank SMS |
| ISS-007 | P0 | Voice Entry Subsystem | Stale service call signatures and audio engine leak on dismiss | REVIEW_REPORT.md Cluster 2 | AC-ARCH-2 | FIXED | Reconciled fetchAccounts/fetchCategories/createTransaction/learnRule and added onDisappear cleanup |
| ISS-008 | P0 | Confidence Scoring / Diagnostics | Inconsistent ConfidenceScore property callsites | REVIEW_REPORT.md Cluster 2 | AC-PARSE-3 | FIXED | Standardized ConfidenceScore.Tier, score, rawScore, formattedPercentage |
| ISS-009 | P0 | Account Taxonomy | Missing .savings and .investment cases in AccountType | REVIEW_REPORT.md Cluster 2 | AC-ARCH-1 | FIXED | Added cases with display names and icons, grouped in bankAccounts |
| ISS-010 | P0 | Review Queue & Export Tests | Missing .ocr case in InputSource, stale saveTransaction test calls | REVIEW_REPORT.md Cluster 2 | AC-DATA-1 | FIXED | Added .ocr case, durable SwiftData updates, and updated tests to createTransaction |
| ISS-011 | P1 | Manual Composer & Accounting | Edit mode created new transactions, transfer lacked validation | REVIEW_REPORT.md Cluster 3 | AC-FIN-1 | FIXED | Dispatches updateTransaction on editing ID, validates src != dst, auto-routes ATM cash |
| ISS-012 | P1 | Account Service & Net Worth | Account edit dropped balance update, multi-currency summed blindly | REVIEW_REPORT.md Cluster 3 | AC-FIN-1 / GT-67 | FIXED | Persists current/opening balance, groups net worth by currency |
| ISS-013 | P1 | Biometrics & Privacy | Biometrics toggle was disconnected from LocalAuthentication | REVIEW_REPORT.md Cluster 4 | AC-SEC-1 / GT-66 | FIXED | Added LAContext biometrics, full-screen BiometricLockView, and scenePhase background lock |
| ISS-014 | P1 | Backup Restore Atomic Integrity | Restore deleted database before validating payload, lost fingerprints | REVIEW_REPORT.md Cluster 4 | AC-DATA-1 / GT-68 | FIXED | Staged SHA-256 validation prior to deletion, included ImportFingerprintRecord in backups |
| ISS-015 | P2 | CSV Formula Sanitizer | Space-padded formula trigger bypass risk | REVIEW_REPORT.md Cluster 4 | AC-SEC-1 / GT-58 | FIXED | Trimmed leading whitespace before checking formula triggers (=, +, -, @, \t, \r) |

