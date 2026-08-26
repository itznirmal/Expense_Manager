# Expense Manager — Project Memory & Orchestration Rules

## 1. Project Context
- **Target Platform**: iOS Application (iOS 17.0+ / iOS 18+)
- **Primary Tech Stack**: Swift, SwiftUI, SwiftData, Swift Concurrency, Swift Charts, LocalAuthentication
- **Workspace Location**: `C:\Users\Nirmal\Documents\APPDEV_FAST\Expense_Manager`

---

## 2. Multi-Agent Orchestration Protocol
- **Master Orchestrator**: Main agent controls feature progression, token economy, phase sequencing, and loop execution.
- **Autonomous Night Execution**: Does not pause or stall on implementation steps; loops through feature slices autonomously until all requirements and verifications pass.
- **Specialized Subagents**:
  - `ios_implementer`: Dedicated Swift/SwiftUI coder executing vertical slices (Model → ViewModel → View → Tests).
  - `ios_reviewer`: Dedicated iOS reviewer conducting 3-Axis audits (Standards, Spec, Adversarial/Edge Cases).
  - `ios_resource_agent`: Resource and architectural blueprint researcher.
- **Gauntlet Quality Protocol (Adapted for Windows Environment)**:
  - Operates on: **BUILD → STATIC OBSERVE → CRITIQUE → FIX → VERIFY (Static/Structural/Schema)**.
  - Since Windows cannot compile native Swift/Xcode targets or launch iOS simulators, compilation and UI execution are designated as macOS manual evidence gates.
  - Verification focuses on 100% syntactically correct, modern Swift 6 / iOS 18 code, schema integrity, and rigorous static adversarial review.
  - Single source of truth tracked in [`QUALITY_BAR.md`](file:///C:/Users/Nirmal/Documents/APPDEV_FAST/Expense_Manager/QUALITY_BAR.md), [`ISSUES.md`](file:///C:/Users/Nirmal/Documents/APPDEV_FAST/Expense_Manager/ISSUES.md), and [`CHECKPOINT.md`](file:///C:/Users/Nirmal/Documents/APPDEV_FAST/Expense_Manager/CHECKPOINT.md).
- **Token Optimization Strategy**:
  - Keep master orchestrator context clean and lightweight by delegating verbose code generation and deep file audits to subagents.
  - Subagents use appropriate model tiers (`flash` for fast lookups/reviews/straightforward slices, `inherit` or `pro` for complex logic).
  - Summarize results concisely at orchestrator milestones.

---

## 3. Engineering & Domain Invariants
1. **Financial Math**: Always use `Decimal` for currency amounts, balances, and budgets (NEVER `Double` or `Float`).
2. **Swift Concurrency**: UI classes annotated with `@MainActor`, cross-boundary objects conform to `Sendable`.
3. **State Management**: Use modern Swift `Observation` framework (`@Observable`) and `@Bindable`.
4. **Offline Persistence**: SwiftData schemas with explicit relationships and cascade rules.
5. **Security & Privacy**:
   - Biometric authentication fails closed.
   - CSV export formulas neutralized (`=`, `+`, `-`, `@` escaped).
   - Zero sensitive logging.
6. **Test Rigor**: Strict in-memory SwiftData container unit testing, covering edge cases (zero amount, boundary dates, category deletion).
