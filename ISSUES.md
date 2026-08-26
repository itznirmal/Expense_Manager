# Issues Ledger (Gauntlet Protocol)

| ID | Sev | Component | Observed | Evidence | AC | Status | Fix commit |
|---|---|---|---|---|---|---|---|
| ISS-001 | P1 | SwiftDataAccountService | Credit Card net worth subtraction inverted on negative balance | Review Report 4abf473d | AC-FIN-1 | FIXED | Standardized sum of balances across accounts |
| ISS-002 | P1 | SwiftDataTransactionService | Negative transaction amount reverses accounting balance adjustment | Review Report 4abf473d | AC-FIN-1 | FIXED | Normalized candidate amount using abs(amount) |
| ISS-003 | P2 | FinancialEngineTests | Missing test coverage for Credit Card Net Worth with transactions | Review Report 4abf473d | AC-FIN-1 | FIXED | Added credit card expense/payment & negative amount test cases |
