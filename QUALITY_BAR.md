# Quality Bar & Acceptance Criteria (Gauntlet Protocol)

> **Frozen as of 2026-08-26 against Master Plan**. Edit only on explicit user instruction, and log edits.

## 1. Architectural & Platform Criteria
- **AC-ARCH-1**: Feature-oriented modular architecture (`App/`, `Domain/`, `Persistence/`, `Transactions/`, `Accounts/`, `Categories/`, `SmartEntry/`, `Parsing/`, `Voice/`, `AppIntents/`, `Imports/`, `Budgets/`, `Analytics/`, `Search/`, `Settings/`, `SharedUI/`, `Tests/`).
- **AC-ARCH-2**: Zero business or persistence logic directly in SwiftUI views. Use `@Observable` ViewModels with `@MainActor` isolation and dependency injection via service protocols.
- **AC-ARCH-3**: Unified Transaction Pipeline: All input methods (Manual, Smart Text, Voice, Siri, SMS Shortcuts, OCR) map to `TransactionCandidate` before persistence.

## 2. Financial Precision & Integrity
- **AC-FIN-1**: All monetary amounts, balances, and budgets must be represented as `Decimal`. No `Double`/`Float` operations in financial calculations.
- **AC-FIN-2**: Deterministic arithmetic for balance updates, monthly spend totals, and budget pace. AI/LLM is never used to compute financial sums.
- **AC-FIN-3**: Account transfers (Transfer In/Out) update account balances without inflating spending or income statistics.

## 3. Parsing, SMS Automation & Safety Invariants
- **AC-PARSE-1**: Hybrid 3-Layer Parser: Layer 1 (Deterministic regex/extractors), Layer 2 (Learned merchant rules), Layer 3 (Structured LLM/Foundation Model fallback for ambiguity).
- **AC-PARSE-2**: Safety Classification: Non-transaction messages (`FAILED_PAYMENT`, `DECLINED_PAYMENT`, `OTP`, `BALANCE_ALERT`, `MARKETING`, `CARD_BLOCKED`) must NEVER generate a transaction.
- **AC-PARSE-3**: Confidence Engine & Review Queue: Confidence score assigned to all candidates (0.90–1.00 Auto-save eligible, 0.65–0.89 Review recommended, <0.64 Review required). Low-confidence items route to `ReviewQueue`.
- **AC-PARSE-4**: Duplicate Protection: Multi-attribute `ImportFingerprint` (hash, amount, merchant, account last 4, ref, timestamp) prevents importing the same message/event twice.

## 4. Privacy & Security Invariants
- **AC-SEC-1**: Default to 100% on-device processing. No raw SMS text persisted. Only sanitized metadata (e.g. `•••• 4321`, transaction ref, hash) stored.
- **AC-SEC-2**: Sensitive data protection: Zero financial/SMS message logging in production logs. Biometric authentication (`LocalAuthentication`) fails closed upon cancellation or lockout.
- **AC-SEC-3**: Export Sanitization: CSV and file exports neutralize Formula Injection attacks (`=`, `+`, `-`, `@` escaped).

## 5. UI/UX & Human Interface Guidelines
- **AC-HIG-1**: Support Dynamic Type, system Light/Dark mode semantic colors, and minimum 44x44 pt tap targets.
- **AC-HIG-2**: Fast manual transaction composer (loggable in 2–3 seconds), smart text composer with instant candidate review card, and glanceable dashboard.

---

## Gauntlet Validation Evidence (Phase 7 Completion)
**Status**: All Criteria Verified - **PASS** (2026-08-26)

### Test Suite Mapping & Lineage
*   **AC-ARCH 1-3**: Validated by `FoundationTests/ArchitectureFoundationTests.swift` and manual code inspection of dependency injection logic and layered groupings.
*   **AC-FIN 1-3**: Validated by `FinancialEngineTests/FinancialEngineTests.swift` (`Decimal` assertions, multi-currency isolation, transaction CRUD validation).
*   **AC-PARSE 1-4**: Validated by `ParserTests/HybridParserTests.swift`, `SMSParsingTests/BankSMSParserTests.swift`, `SMSParsingTests/SMSSafetyClassifierTests.swift`, and `FinancialEngineTests/DuplicatePreventionTests.swift`.
*   **AC-SEC 1-3**: Validated by `SecurityTests/DataExportAndSecurityTests.swift` (CSV formula sanitization) and `VoiceAndIntentTests/SMSSafetyClassifierTests.swift`. Biometric app lock validation enforced via UI test plans.
*   **AC-HIG 1-2**: Validated by Snapshot tests / Preview coverage for all Feature components.

For detailed mappings per feature and line reference, refer to `RELEASE_GATES.md`.
