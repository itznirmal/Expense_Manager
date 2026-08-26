//
//  HybridParserTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Unit Test Suite for Hybrid Parser Subsystem.
//

import XCTest
@testable import ExpenseManager

final class HybridParserTests: XCTestCase {
    
    // MARK: - 1. InputNormalizer Tests
    
    func testInputNormalizerUnicodeQuotesAndDashes() {
        let raw = "“Paid” to Swiggy — ‘dinner’ … 520"
        let normalized = InputNormalizer.normalize(raw)
        XCTAssertEqual(normalized, "\"Paid\" to Swiggy - 'dinner' ... 520")
    }
    
    func testInputNormalizerWhitespaceCollapse() {
        let raw = "  Swiggy    520   \n\t  from   HDFC   "
        let normalized = InputNormalizer.normalize(raw)
        XCTAssertEqual(normalized, "Swiggy 520 from HDFC")
    }
    
    func testInputNormalizerTokenize() {
        let tokens = InputNormalizer.tokenize("Uber 460 yesterday evening")
        XCTAssertEqual(tokens, ["Uber", "460", "yesterday", "evening"])
    }
    
    // MARK: - 2. AmountParser Tests (10+ Variations)
    
    func testAmountParserRupeeSymbolPrefix() {
        let result = AmountParser.extractAmount(from: "Spent ₹520 at Starbucks")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, Decimal(520))
        XCTAssertEqual(result?.currencyCode, "INR")
    }
    
    func testAmountParserRupeeSymbolWithSpace() {
        let result = AmountParser.extractAmount(from: "₹ 1,450.50 for groceries")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, Decimal(1450.50))
        XCTAssertEqual(result?.currencyCode, "INR")
    }
    
    func testAmountParserRsPrefixWithPeriod() {
        let result = AmountParser.extractAmount(from: "Rs. 2500 paid for electricity")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, Decimal(2500))
        XCTAssertEqual(result?.currencyCode, "INR")
    }
    
    func testAmountParserINRPrefix() {
        let result = AmountParser.extractAmount(from: "INR 85000 credited")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, Decimal(85000))
        XCTAssertEqual(result?.currencyCode, "INR")
    }
    
    func testAmountParserRupeesSuffix() {
        let result = AmountParser.extractAmount(from: "Paid 520 rupees to Swiggy")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, Decimal(520))
        XCTAssertEqual(result?.currencyCode, "INR")
    }
    
    func testAmountParserRsSuffix() {
        let result = AmountParser.extractAmount(from: "350.75 rs spent")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, Decimal(350.75))
        XCTAssertEqual(result?.currencyCode, "INR")
    }
    
    func testAmountParserUSDDollar() {
        let result = AmountParser.extractAmount(from: "$12.99 subscription")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, Decimal(12.99))
        XCTAssertEqual(result?.currencyCode, "USD")
    }
    
    func testAmountParserEuro() {
        let result = AmountParser.extractAmount(from: "€45.50 train ticket")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, Decimal(45.50))
        XCTAssertEqual(result?.currencyCode, "EUR")
    }
    
    func testAmountParserBareNumber() {
        let result = AmountParser.extractAmount(from: "Swiggy 520")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, Decimal(520))
        XCTAssertEqual(result?.currencyCode, "INR")
    }
    
    func testAmountParserBareNumberWithComma() {
        let result = AmountParser.extractAmount(from: "Flight booking 12,450")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.amount, Decimal(12450))
    }
    
    // MARK: - 3. DateParser Tests (Relative & Absolute)
    
    func testDateParserToday() {
        let calendar = Calendar.current
        var comp = DateComponents()
        comp.year = 2026
        comp.month = 8
        comp.day = 25
        comp.hour = 14
        let refDate = calendar.date(from: comp)!
        
        let result = DateParser.extractDate(from: "Coffee 350 today", referenceDate: refDate, calendar: calendar)
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.day, from: result!.date), 25)
    }
    
    func testDateParserYesterday() {
        let calendar = Calendar.current
        var comp = DateComponents()
        comp.year = 2026
        comp.month = 8
        comp.day = 25
        let refDate = calendar.date(from: comp)!
        
        let result = DateParser.extractDate(from: "Dinner 1200 yesterday night", referenceDate: refDate, calendar: calendar)
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.day, from: result!.date), 24)
    }
    
    func testDateParserLastFriday() {
        let calendar = Calendar.current
        var comp = DateComponents()
        comp.year = 2026
        comp.month = 8
        comp.day = 25 // Tuesday (weekday 3)
        let refDate = calendar.date(from: comp)!
        
        let result = DateParser.extractDate(from: "Movies 450 last Friday", referenceDate: refDate, calendar: calendar)
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.weekday, from: result!.date), 6) // Friday is weekday 6
    }
    
    func testDateParserExplicitMonthDay() {
        let calendar = Calendar.current
        var comp = DateComponents()
        comp.year = 2026
        comp.month = 8
        comp.day = 1
        let refDate = calendar.date(from: comp)!
        
        let result = DateParser.extractDate(from: "Flight 4500 on 25 Aug 2026", referenceDate: refDate, calendar: calendar)
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.day, from: result!.date), 25)
        XCTAssertEqual(calendar.component(.month, from: result!.date), 8)
        XCTAssertEqual(calendar.component(.year, from: result!.date), 2026)
    }
    
    func testDateParserDelimitedDate() {
        let calendar = Calendar.current
        let result = DateParser.extractDate(from: "Bill paid on 25/08/2026", calendar: calendar)
        XCTAssertNotNil(result)
        XCTAssertEqual(calendar.component(.day, from: result!.date), 25)
        XCTAssertEqual(calendar.component(.month, from: result!.date), 8)
        XCTAssertEqual(calendar.component(.year, from: result!.date), 2026)
    }
    
    // MARK: - 4. DirectionClassifier Tests
    
    func testDirectionExpense() {
        XCTAssertEqual(TransactionDirectionClassifier.classify(text: "Paid 520 to Swiggy").type, .expense)
        XCTAssertEqual(TransactionDirectionClassifier.classify(text: "Debited for electricity bill").type, .expense)
        XCTAssertEqual(TransactionDirectionClassifier.classify(text: "Spent 450 at Starbucks").type, .expense)
    }
    
    func testDirectionIncome() {
        XCTAssertEqual(TransactionDirectionClassifier.classify(text: "Salary 85000 credited to account").type, .income)
        XCTAssertEqual(TransactionDirectionClassifier.classify(text: "Received 5000 bonus from client").type, .income)
        XCTAssertEqual(TransactionDirectionClassifier.classify(text: "Interest credited 450").type, .income)
    }
    
    func testDirectionRefund() {
        XCTAssertEqual(TransactionDirectionClassifier.classify(text: "Refund of 1450 credited for returned item").type, .refund)
    }
    
    func testDirectionTransfer() {
        XCTAssertEqual(TransactionDirectionClassifier.classify(text: "Transferred 10000 to savings account").type, .transfer)
        XCTAssertEqual(TransactionDirectionClassifier.classify(text: "Self transfer of 5000").type, .transfer)
    }
    
    func testDirectionCashWithdrawal() {
        XCTAssertEqual(TransactionDirectionClassifier.classify(text: "Cash withdrawal of 2000 from ATM").type, .cashWithdrawal)
    }
    
    // MARK: - 5. MerchantNormalizer Tests
    
    func testMerchantNoiseStripping() {
        let result1 = MerchantNormalizer.normalizeMerchantName("SWIGGY*BANGALORE PVT LTD")
        XCTAssertEqual(result1.normalizedName, "Swiggy")
        XCTAssertEqual(result1.inferredCategory, "Food & Dining")
        
        let result2 = MerchantNormalizer.normalizeMerchantName("UBER INDIA TECHNOLOGY PVT LTD")
        XCTAssertEqual(result2.normalizedName, "Uber")
        XCTAssertEqual(result2.inferredCategory, "Transportation")
        
        let result3 = MerchantNormalizer.normalizeMerchantName("POS/STARBUCKS COFFEE/MUMBAI")
        XCTAssertEqual(result3.normalizedName, "Starbucks")
        XCTAssertEqual(result3.inferredCategory, "Food & Dining")
        
        let result4 = MerchantNormalizer.normalizeMerchantName("INFO*NETFLIX ENTERTAINMENT")
        XCTAssertEqual(result4.normalizedName, "Netflix")
        XCTAssertEqual(result4.inferredCategory, "Entertainment")
        
        let result5 = MerchantNormalizer.normalizeMerchantName("BLINKIT COMMERCE PRIVATE LIMITED")
        XCTAssertEqual(result5.normalizedName, "Blinkit")
        XCTAssertEqual(result5.inferredCategory, "Groceries")
    }
    
    // MARK: - 6. AccountHintParser Tests
    
    func testAccountHintBankAndCard() {
        let result = AccountHintParser.extractAccountHint(from: "Paid 520 via HDFC Bank card ending 8432")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.bankName, "HDFC Bank")
        XCTAssertEqual(result?.lastFour, "8432")
        XCTAssertEqual(result?.paymentMethod, .creditCard)
        XCTAssertEqual(result?.accountSuggestion, "HDFC Bank •••• 8432")
    }
    
    func testAccountHintMaskedAccount() {
        let result = AccountHintParser.extractAccountHint(from: "Debited from SBI A/C XX4321")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.bankName, "State Bank of India")
        XCTAssertEqual(result?.lastFour, "4321")
    }
    
    func testAccountHintUPIChannel() {
        let result = AccountHintParser.extractAccountHint(from: "Paid via Google Pay")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.bankName, "Google Pay")
        XCTAssertEqual(result?.paymentMethod, .upi)
    }
    
    // MARK: - 7. ReferenceNumberParser Tests
    
    func testReferenceUPIVPA() {
        let result = ReferenceNumberParser.extractReference(from: "Paid to swiggy@upi Ref 482019283741")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.upiVPA, "swiggy@upi")
        XCTAssertEqual(result?.referenceNumber, "482019283741")
    }
    
    func testReferenceUTR() {
        let result = ReferenceNumberParser.extractReference(from: "Txn successful. UTR: 123456789012")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.utr, "123456789012")
    }
    
    // MARK: - 8. DeterministicTransactionParser End-to-End Tests
    
    func testDeterministicParserSwiggyStandard() {
        let draft = DeterministicTransactionParser.parse(text: "Swiggy 520 yesterday")
        XCTAssertEqual(draft.amount, Decimal(520))
        XCTAssertEqual(draft.merchantName, "Swiggy")
        XCTAssertEqual(draft.inferredCategory, "Food & Dining")
        XCTAssertEqual(draft.type, .expense)
    }
    
    func testDeterministicParserSalaryTransfer() {
        let draft = DeterministicTransactionParser.parse(text: "Salary 85000 credited to HDFC Bank today")
        XCTAssertEqual(draft.amount, Decimal(85000))
        XCTAssertEqual(draft.type, .income)
        XCTAssertEqual(draft.accountSuggestion, "HDFC Bank")
    }
    
    func testDeterministicParserUberFromCard() {
        let draft = DeterministicTransactionParser.parse(text: "Paid ₹460 to Uber from ICICI card 9876")
        XCTAssertEqual(draft.amount, Decimal(460))
        XCTAssertEqual(draft.merchantName, "Uber")
        XCTAssertEqual(draft.inferredCategory, "Transportation")
        XCTAssertEqual(draft.accountSuggestion, "ICICI Bank •••• 9876")
        XCTAssertEqual(draft.paymentMethod, .creditCard)
    }
}
