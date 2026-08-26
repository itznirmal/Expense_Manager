# Expense Tracker with Smart Entry, Voice, Siri, and SMS Automation
## LLM Implementation Master Plan

**Target:** iOS 26+  
**Primary stack:** SwiftUI + SwiftData + App Intents + Shortcuts + Speech + Vision + WidgetKit  
**Development style:** phased, test-driven, quality-gated  
**Goal:** Build a polished native expense tracker where users can log transactions manually, by natural-language text, by voice, through Siri/Shortcuts, and through an iOS Shortcuts automation that receives bank/payment SMS messages and converts them into transactions.

---

# 1. Product Vision

Build a premium iOS expense tracker that minimizes manual bookkeeping.

The core promise is:

> **Spend normally. Your tracker catches up automatically.**

Users should be able to record an expense in progressively easier ways:

1. Manual transaction entry
2. Smart text entry
3. Voice entry
4. Siri / App Shortcut
5. Incoming bank/payment SMS automation
6. Receipt scan
7. Payment screenshot import
8. Bulk pasted transactions

All input methods must feed the **same normalized transaction pipeline**.

Do not build separate independent parsing systems for each input source.

---

# 2. Important iOS Constraint

An ordinary iOS app cannot directly read the user's SMS inbox.

The intended workflow is:

```text
Incoming bank/payment SMS
        ↓
Apple Shortcuts Personal Automation
        ↓
Shortcut receives message as Shortcut Input
        ↓
Our App Intent: "Import Bank Message"
        ↓
Local parser / optional Foundation Model
        ↓
TransactionCandidate
        ↓
Duplicate detection
        ↓
Confidence validation
        ↓
Save / Review / Ignore
```

The user must create/authorize the Shortcuts automation.

The app should provide:

- App Intent
- App Shortcut
- onboarding instructions
- troubleshooting diagnostics
- parser test screen

Do not design any architecture that assumes unrestricted programmatic access to the SMS inbox.

---

# 3. Non-Negotiable Engineering Principles

The implementation agent must follow these rules.

## 3.1 Architecture

Use feature-oriented architecture.

Recommended modules/folders:

```text
App/
Domain/
Persistence/
Transactions/
Accounts/
Categories/
SmartEntry/
Parsing/
Voice/
AppIntents/
Imports/
Budgets/
Analytics/
Search/
Settings/
Widgets/
Notifications/
Monetization/
SharedUI/
Tests/
```

Business logic must not live directly inside SwiftUI views.

Use protocols and dependency-injected services where reasonable.

---

## 3.2 Financial correctness

Do not use `Double` as the authoritative representation of money.

Use:

- `Decimal`
- or integer minor units where appropriate

Financial totals, budgets, account balances, and analytics must always be deterministic.

Do not ask an LLM to calculate financial totals.

AI may explain or classify data, but arithmetic must come from trusted application code.

---

## 3.3 One transaction pipeline

Every source must eventually produce the same normalized type:

```text
TransactionInput
      ↓
InputNormalizer
      ↓
TransactionParser
      ↓
TransactionCandidate
      ↓
Merchant / category rules
      ↓
Confidence engine
      ↓
Transaction
```

Supported input sources:

```text
manual
smartText
voice
siri
sms
shortcut
receipt
screenshot
bulkImport
```

---

## 3.4 Privacy

Default to local processing.

Prefer:

- SwiftData local persistence
- deterministic parsing
- on-device Foundation Models when available
- Vision OCR on-device
- local merchant rules
- local analytics

Do not persist raw bank SMS content unless explicitly necessary.

Prefer storing:

- sanitized metadata
- transaction reference where safe
- account/card last four digits only
- one-way hash/fingerprint of the source input

Never store full bank account numbers or full card numbers.

---

# 4. Canonical Domain Models

Freeze these contracts before building large amounts of UI.

---

## 4.1 Transaction

Recommended properties:

```swift
Transaction {
    id
    type
    amount
    currencyCode
    merchantName
    categoryID
    accountID
    destinationAccountID
    paymentMethod
    transactionDate
    notes
    tags
    location
    source
    sourceReference
    confidence
    createdAt
    updatedAt
}
```

Transaction types:

```text
expense
income
refund
transfer
cashWithdrawal
unknown
```

Input sources:

```text
manual
smartText
voice
siri
sms
shortcut
receipt
screenshot
bulkImport
```

Important:

Transfers between the user's own accounts must not inflate income or spending statistics.

---

## 4.2 Account

```swift
Account {
    id
    name
    type
    currencyCode
    openingBalance
    icon
    colorToken
    lastFour
    isArchived
    createdAt
}
```

Types:

```text
cash
bank
creditCard
wallet
other
```

---

## 4.3 Category

```swift
Category {
    id
    name
    parentCategoryID
    icon
    colorToken
    type
    isSystem
}
```

Category type:

```text
expense
income
both
```

---

## 4.4 TransactionCandidate

All parsers should return this object before permanent saving.

```swift
TransactionCandidate {
    type
    amount
    currencyCode
    merchantName
    categorySuggestion
    accountSuggestion
    destinationAccountSuggestion
    paymentMethod
    transactionDate
    notes
    tags
    source
    sourceReference
    confidence
    needsReview
    warnings
}
```

---

## 4.5 MerchantRule

```swift
MerchantRule {
    normalizedMerchant
    preferredCategoryID
    preferredAccountID
    preferredTags
    matchPattern
    confidence
    createdAt
    updatedAt
}
```

Examples:

```text
SWIGGY → Dining
SHELL → Fuel
UBER → Transport
NETFLIX → Entertainment
```

---

## 4.6 ImportFingerprint

Used to prevent duplicate imports.

Possible fields:

```swift
ImportFingerprint {
    id
    sourceHash
    amount
    normalizedMerchant
    accountLastFour
    transactionReference
    approximateTimestamp
    source
}
```

---

# 5. Parsing Architecture

Implement a hybrid parser.

Do not send every transaction string directly to an LLM.

Use three layers.

---

## Layer 1 — Deterministic parser

Extract obvious information using trusted code.

Examples of amount forms:

```text
₹520
Rs 520
Rs. 520
INR 520
520 rupees
$12
12 USD
```

Date language:

```text
today
yesterday
last Friday
25 Aug
25/08/2026
```

Transaction signals:

```text
paid
spent
debited
charged
received
credited
salary
refund
refunded
transferred
withdrawn
```

Also parse:

- account/card last four digits
- UPI VPA
- UTR/reference numbers
- bank names
- transaction direction
- merchant candidates

---

## Layer 2 — Local learned rules

Use previously confirmed corrections.

Examples:

```text
Swiggy → Dining
Uber → Transport
Shell → Fuel
Amazon Fresh → Groceries
```

The app should improve over time without requiring cloud AI.

---

## Layer 3 — Foundation Model

Use Apple's Foundation Models only for ambiguity resolution when available.

Prefer structured guided generation into Swift types rather than free-form text.

Examples of AI tasks:

- infer merchant from conversational text
- infer likely category
- distinguish note from merchant
- identify whether a phrase implies refund/income/expense
- extract structured fields from irregular text

The app must still work without Apple Intelligence.

Fallback order:

```text
Deterministic Parser
        ↓
Merchant Rules
        ↓
Foundation Model if available
        ↓
Optional cloud parser only if explicitly enabled
```

---

# 6. Confidence Engine

Every parser output must receive a confidence score.

Suggested policy:

```text
0.90–1.00    High confidence
0.65–0.89    Review recommended
0.00–0.64    Do not auto-save
```

Auto-imported SMS messages should only save automatically when:

- amount is confidently extracted
- direction is clear
- duplicate check passes
- message is classified as a real completed transaction
- confidence threshold is met

Otherwise route to a Review Queue.

---

# 7. SMS Classification Safety

The SMS classifier must distinguish:

```text
VALID_TRANSACTION
REFUND
TRANSFER
CASH_WITHDRAWAL
BALANCE_ALERT
OTP
MARKETING
PAYMENT_REMINDER
FAILED_PAYMENT
DECLINED_PAYMENT
SECURITY_ALERT
CARD_BLOCKED
UNKNOWN
```

A critical release test:

> "Your payment of ₹12,450 FAILED"

must **never** become an expense.

Similarly:

> "OTP 847221 for INR 9,999 purchase"

must **never** become a transaction.

---

# 8. Phased Implementation Plan

Do not implement everything in one pass.

Complete each phase, run the app, test it, inspect the result, fix defects, and only then proceed.

---

# PHASE 0 — Repository and Architecture Foundation

## Objective

Create a clean native iOS project that can support all later features.

## Tasks

- Create native SwiftUI app
- Target iOS 26+
- Configure SwiftData
- Create folder/module structure
- Add dependency container
- Add service protocols
- Add unit test target
- Create minimal root navigation
- Add feature flags where useful
- Add logging subsystem
- Document architecture

## Acceptance criteria

- Project builds
- Simulator launches
- SwiftData container initializes
- Unit test target runs
- No major business logic inside Views
- Architecture README exists

Do not proceed until these are true.

---

# PHASE 1 — Financial Data Engine

## Objective

Build correct transaction, account, and category persistence.

## Implement

- Transaction model
- Account model
- Category model
- Tag model
- MerchantRule model
- ImportFingerprint model

## Required behaviors

Create, edit, delete, archive, and query:

- accounts
- categories
- transactions
- tags

Support:

- expense
- income
- refund
- transfer
- cash withdrawal

## Tests

At minimum:

- INR money precision
- expense balance effect
- income balance effect
- refund behavior
- transfer between accounts
- edit transaction
- delete transaction
- archived account handling
- category aggregation
- month totals

---

# PHASE 2 — Manual Transaction Entry

## Objective

Make basic transaction logging excellent before AI features.

## UI requirements

Fast composer with:

```text
Amount
Expense / Income / Transfer
Merchant
Category
Account
Date
Note
Tags
Location
Save
```

The common path should require minimal taps.

## UX goal

A normal expense should be loggable in roughly 2–3 seconds after the entry screen opens.

## Acceptance criteria

- keyboard behavior is polished
- currency formatting is correct
- validation is clear
- recent merchants/categories can be reused
- edit workflow uses same domain service
- app remains fully usable without AI

---

# PHASE 3 — Smart Text Entry

## Objective

Allow natural-language transaction entry.

Examples:

```text
swiggy 520
```

```text
Paid ₹520 to Swiggy for dinner
```

```text
Starbucks coffee 350 yesterday
```

```text
Salary 85000 today
```

```text
Uber 460 from HDFC credit card
```

## Output

Each string becomes a `TransactionCandidate`.

## UI

Show a review card:

```text
₹520
Swiggy
Dining
HDFC Credit Card
Today

Confidence: High

[Save]
```

Allow correction of every field.

Corrections should optionally feed MerchantRule learning.

---

# PHASE 4 — Hybrid Parser

## Objective

Build production parsing instead of relying on one LLM prompt.

## Implement

- InputNormalizer
- CurrencyParser
- AmountParser
- DateParser
- MerchantNormalizer
- TransactionDirectionClassifier
- AccountHintParser
- ReferenceNumberParser
- deterministic transaction parser
- merchant rule resolver
- Foundation Model resolver
- parser orchestrator

## Acceptance criteria

A deterministic parser handles simple common transactions without AI.

The Foundation Model only resolves ambiguity.

---

# PHASE 5 — Confidence and Review Queue

## Objective

Prevent bad automatic imports.

## Implement

- confidence scoring
- warnings
- review queue
- accept/reject/edit flow
- source visibility
- "why this needs review" diagnostics

Example:

```text
Needs Review

₹1,299
AMAZON
Shopping
HDFC •••• 8432

Reason:
Merchant confidence only 72%

[Edit]
[Save]
[Ignore]
```

---

# PHASE 6 — Voice Entry

## Objective

Use voice as another adapter into Smart Entry.

## Flow

```text
Microphone
   ↓
Speech transcription
   ↓
SmartEntryParser
   ↓
TransactionCandidate
   ↓
Review
```

Example:

> "Spent five hundred and twenty rupees on Swiggy for dinner."

Expected result:

```text
Expense
₹520
Swiggy
Dining
Today
```

Do not build separate business logic for voice.

---

# PHASE 7 — App Intents and Siri

## Objective

Expose the most useful transaction actions to iOS system surfaces.

Initial intents:

```text
Add Transaction
Import Bank Message
Open Transaction Entry
Check Spending
```

Keep App Intent types thin.

Business logic should call shared services.

## Suggested Siri use

```text
"Add ₹350 Starbucks to <AppName>"
```

```text
"Tell <AppName> I spent ₹840 on Swiggy"
```

## Acceptance criteria

- intent target builds
- Shortcuts discovers the actions
- action works from Shortcuts
- Siri invocation routes correctly
- no duplicated parser logic

---

# PHASE 8 — SMS / Shortcuts Proof of Concept

## Objective

Prove the hardest integration before polishing the full app.

## Required flow

```text
Incoming message
   ↓
Shortcuts Personal Automation
   ↓
Shortcut Input
   ↓
Import Bank Message App Intent
   ↓
BankMessageParser
   ↓
TransactionCandidate
   ↓
Save or Review
```

## App Intent

Conceptually:

```swift
ImportBankMessageIntent
```

Input:

```swift
message: String
```

The intent must pass the text into the shared parser service.

## Proof-of-concept acceptance test

Using at least one real anonymized Indian bank/payment message:

1. automation receives message text
2. App Intent runs
3. amount is extracted
4. debit/credit direction is correct
5. merchant is detected where possible
6. duplicate fingerprint is created
7. transaction appears in SwiftData
8. user receives confirmation or review notification

Do not proceed to broader SMS support until this works end-to-end.

---

# PHASE 9 — Indian Bank SMS Parser

## Objective

Support common Indian financial SMS formats.

Begin with fixtures for:

- HDFC Bank
- ICICI Bank
- SBI
- Axis Bank
- Kotak
- Federal Bank
- Canara Bank
- major credit-card alerts
- UPI alerts

Example formats:

```text
Rs.500.00 debited from A/c XX4321 to VPA swiggy@upi
```

```text
INR 2,480 spent using HDFC Bank Card ending 8432 at AMAZON
```

```text
Your A/c XX1122 is debited by Rs 460.00 via UPI to UBER INDIA
```

```text
Rs 85,000 credited to A/c XX4321. Salary...
```

## Extract

```text
amount
currency
credit/debit
merchant
bank
account last four
card last four
UPI VPA
reference/UTR
date/time
```

## Privacy

Never persist complete bank/card numbers.

Store only sanitized identifiers such as:

```text
•••• 4321
```

---

# PHASE 10 — Duplicate Prevention

## Objective

Never create multiple transactions from the same notification.

## Build

Create a deterministic import fingerprint using some combination of:

```text
normalized amount
normalized merchant
transaction date/time
account last four
transaction reference
source
hash of normalized message
```

Possible import outcomes:

```text
IMPORTED
DUPLICATE
NOT_TRANSACTION
NEEDS_REVIEW
FAILED
```

## Acceptance criteria

Running the same input twice produces one transaction.

---

# PHASE 11 — SMS Setup Wizard and Diagnostics

## Objective

Make Shortcuts setup understandable for non-technical users.

## Setup screen concept

```text
Automatic Transaction Import

Your bank already sends spending alerts.
Use those alerts to record expenses automatically.

✓ No bank password
✓ No bank login
✓ Messages can be processed locally

[Set Up Auto Import]
```

## Setup guide should explain

```text
Shortcuts
→ Automation
→ Message
→ Run Immediately
→ New Blank Automation
→ <AppName>
→ Import Bank Message
→ Message = Shortcut Input
```

## Diagnostics

Show:

```text
Automation Status
Last Import
Imported Today
Needs Review
Duplicates
Ignored Messages
Parser Version
```

Include:

- Test Parser
- View Setup Guide
- Send Sample Test
- Copy Diagnostics

---

# PHASE 12 — Merchant Intelligence

## Objective

Learn from user corrections.

Examples:

```text
SWIGGY → Dining
SHELL → Fuel
UBER → Transport
NETFLIX → Entertainment
```

When users repeatedly make the same correction, offer:

> Always categorize Swiggy as Dining?

If accepted, persist a MerchantRule.

Rules must be editable in Settings.

---

# PHASE 13 — Home Dashboard

## Objective

Create a premium, glanceable home screen.

Suggested information hierarchy:

```text
Greeting

Spent This Month
₹18,420
↓ 12% vs previous month

Today
Recent Transactions

Spending Pace
₹18,420 / ₹30,000

Top Categories
Dining
Transport
Shopping
```

Avoid overwhelming users with many charts.

Prioritize:

- current spending
- recent activity
- budget pace
- quick Smart Entry

---

# PHASE 14 — Budget System

Support:

```text
weekly
monthly
yearly
custom
```

Support:

- overall budget
- category budget

Example:

```text
Dining
₹6,240 / ₹8,000

Transport
₹2,500 / ₹5,000
```

All calculations must be deterministic.

---

# PHASE 15 — Analytics

Build:

- daily spend
- weekly spend
- monthly spend
- category breakdown
- merchant breakdown
- account breakdown
- income vs expense
- refund tracking
- spending trend
- month-over-month comparison

Use Swift Charts where appropriate.

Keep analytics fast with large datasets.

---

# PHASE 16 — Receipt Scanning

## Objective

Capture transaction details from receipts.

Pipeline:

```text
Camera
  ↓
Vision / VisionKit OCR
  ↓
recognized text/document
  ↓
transaction parser
  ↓
TransactionCandidate
  ↓
Review
```

Extract where possible:

```text
merchant
date
subtotal
tax
tip
total
currency
```

Do not save receipt-derived data automatically if confidence is low.

---

# PHASE 17 — Payment Screenshot Import

## Objective

Support screenshots from apps such as:

- Google Pay
- PhonePe
- Paytm
- banking apps
- Amazon
- Swiggy
- other payment screens

Implement Share Extension if appropriate.

Pipeline:

```text
Share screenshot
     ↓
Vision OCR
     ↓
Smart Parser
     ↓
TransactionCandidate
     ↓
Review
```

This is especially important for Indian users.

---

# PHASE 18 — Bulk Text Import

Allow:

```text
Coffee 250
Uber 620
Lunch 450
Petrol 3800
Netflix 649
```

Parser should return multiple candidates.

Review UI:

```text
5 transactions detected

✓ Coffee       ₹250
✓ Uber         ₹620
✓ Lunch        ₹450
✓ Petrol     ₹3,800
✓ Netflix      ₹649

Total        ₹5,769

[Import 5 Transactions]
```

Support selective import.

---

# PHASE 19 — Search

Start with deterministic search.

Examples:

```text
Swiggy
Amazon
₹2000+
July
Dining
HDFC
```

Later add natural-language search:

```text
Swiggy last month
expenses above ₹2,000
petrol this year
Amazon purchases in July
```

Natural language should compile into explicit search filters.

Do not let an LLM invent transaction results.

---

# PHASE 20 — Widgets

Initial widgets:

```text
Today Spend
Month Spend
Budget Progress
Quick Add
```

Later:

```text
Recent Transactions
Category Budget
Spending Heat Map
```

Widgets should use shared domain/query services.

---

# PHASE 21 — Notifications

Useful notifications only.

Examples:

```text
₹840 automatically logged
Swiggy • Dining
```

```text
Dining budget is 80% used.
```

```text
1 imported transaction needs review.
```

```text
7 transactions imported today.
```

Allow granular notification controls.

---

# PHASE 22 — Data Export and Backup

Implement:

- CSV export
- JSON backup
- restore
- local file export
- optional iCloud/CloudKit backup later

Export must preserve:

- date
- amount
- type
- merchant
- category
- account
- notes
- tags
- source

---

# PHASE 23 — Privacy and Security Hardening

Review:

- raw SMS retention
- logging of financial text
- crash-report redaction
- account/card masking
- app lock
- biometric access
- clipboard usage
- screenshot privacy if implemented
- cloud AI opt-in
- analytics opt-in

Never log raw financial messages in production console logs.

---

# PHASE 24 — Monetization

Keep basic manual tracking useful for free.

Possible Free tier:

```text
Manual transactions
Smart text
Basic analytics
Limited accounts
Basic budgets
CSV export
```

Possible Pro tier:

```text
Automatic SMS import
Unlimited accounts
Receipt scanning
Screenshot import
Advanced insights
Widgets
Merchant automation
Cloud backup
Advanced budgets
Bulk import
```

Use StoreKit 2.

RevenueCat may be added if subscription management benefits justify it.

Do not entangle core transaction logic with monetization code.

---

# PHASE 25 — Reliability Gauntlet

Create a large anonymized parser fixture library.

Minimum fixture categories:

```text
HDFC
ICICI
SBI
Axis
Kotak
Federal Bank
Canara Bank
UPI
credit card
debit card
refund
cash withdrawal
salary
transfer
failed payment
declined transaction
OTP
marketing
balance alert
payment reminder
cashback
security alert
```

For every fixture, define the expected classification and parsed fields.

## Critical tests

The following must NEVER become expenses:

```text
Your payment of ₹12,450 FAILED
```

```text
OTP 472910 for INR 9,999 purchase
```

```text
Your available balance is ₹54,320
```

```text
Get 20% cashback on your next card purchase
```

---

# 9. Recommended MVP Scope

Do not build all Phase 0–25 before testing with users.

The first strong production milestone should include:

```text
Phase 0  Architecture
Phase 1  Financial data engine
Phase 2  Manual entry
Phase 3  Smart text
Phase 4  Hybrid parser
Phase 5  Confidence/review
Phase 6  Voice entry
Phase 7  Siri/App Intents
Phase 8  SMS Shortcuts proof of concept
Phase 9  Indian SMS parsing
Phase 10 Duplicate protection
Phase 11 SMS onboarding/diagnostics
Phase 12 Merchant rules
Phase 13 Home dashboard
Phase 15 Basic analytics
Phase 20 Basic widgets
Phase 21 Notifications
Phase 23 Privacy hardening
```

This is already a differentiated iOS expense tracker.

---

# 10. V1.5

After the MVP is stable:

```text
Receipt OCR
Payment screenshot import
Bulk text import
Advanced budgets
Expanded widgets
Merchant learning improvements
Advanced CSV import/export
More Indian bank templates
```

---

# 11. V2

Potential later additions:

```text
Natural-language financial search
AI-generated spending insights
Subscription detection
Recurring expense detection
Cash-flow forecasting
iCloud multi-device sync
Shared/family budgets
Account Aggregator integration
Android version
```

Do not introduce V2 complexity into the initial architecture unless a simple abstraction is needed to avoid a future dead end.

---

# 12. LLM Development Protocol

For **every phase**, follow this exact loop:

```text
PLAN
  ↓
IMPLEMENT
  ↓
BUILD
  ↓
RUN
  ↓
TEST
  ↓
INSPECT UI / LOGS / DATA
  ↓
CRITIQUE
  ↓
FIX
  ↓
RETEST
  ↓
DOCUMENT
```

A phase is not complete merely because:

- code compiles
- UI appears
- tests pass
- feature exists

The implementation must also be inspected for:

- UX quality
- incorrect edge cases
- crashes
- state bugs
- duplicate logic
- accessibility
- data corruption risks
- financial correctness
- privacy leaks
- visual inconsistencies

---

# 13. Rules for the Coding LLM

The implementation agent must obey these rules.

1. Do not rewrite unrelated working code.
2. Do not skip tests to move faster.
3. Do not create mock implementations and call a phase complete.
4. Do not duplicate parsing logic between voice, Siri, SMS, and Smart Entry.
5. Do not put persistence/business logic directly inside SwiftUI views.
6. Do not use floating-point money arithmetic.
7. Do not let AI calculate financial totals.
8. Do not auto-save ambiguous financial messages.
9. Do not persist sensitive raw SMS unnecessarily.
10. Do not silently change previously frozen architecture.
11. Build and run after every meaningful implementation step.
12. Add tests for every parser regression discovered.
13. Maintain a parser fixture library.
14. Document architectural decisions.
15. Prefer simple native Apple frameworks before adding third-party dependencies.

---

# 14. First Implementation Assignment

Start only with **Phase 0**.

Do not implement later features yet.

## Task

Create the iOS project foundation for the expense tracker described in this document.

Target iOS 26+.

Use:

- SwiftUI
- SwiftData
- feature-oriented architecture
- dependency-injected domain services
- unit tests

Create the project/module structure required for future:

- Transactions
- Accounts
- Categories
- Smart Entry
- Parsing
- Voice
- App Intents
- SMS/Shortcuts imports
- Budgets
- Analytics
- Widgets
- Settings

Implement only the minimum code needed to prove:

- project builds
- simulator runs
- navigation shell works
- SwiftData initializes
- service dependency structure works
- tests run successfully

Do not build the final visual design yet.

At the end of the phase, report:

1. files created/changed
2. architecture decisions
3. build result
4. tests executed
5. simulator verification
6. known issues
7. technical debt
8. exact next-phase recommendation

Do not proceed into Phase 1 until Phase 0 has passed all acceptance criteria.

---

# 15. Final Product Quality Bar

The finished app should feel like a polished native iOS product rather than an AI-generated CRUD application.

Success means:

- manual transaction entry is extremely fast
- Smart Entry feels reliable
- voice entry uses the same parser
- Siri works cleanly
- SMS automation is understandable to normal users
- duplicate transactions are aggressively prevented
- failed payments/OTP/marketing messages are safely ignored
- Indian payment formats are handled well
- financial totals are exact
- user data is treated as sensitive by default
- the UI is coherent, premium, accessible, and responsive
- features survive real-world usage rather than only demo data

The hardest early milestone is the end-to-end SMS proof of concept:

> **Real bank/payment SMS → Shortcuts Automation → App Intent → parser → duplicate check → SwiftData transaction → confirmation/review**

Once this works reliably, the largest technical uncertainty in the product has been removed.
