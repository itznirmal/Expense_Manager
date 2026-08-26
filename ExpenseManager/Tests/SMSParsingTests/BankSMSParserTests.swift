//
//  BankSMSParserTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Deterministic Multi-Bank SMS Parser Unit Tests across Top Indian Financial Institutions.
//

import XCTest
@testable import ExpenseManager

final class BankSMSParserTests: XCTestCase {
    
    // MARK: - HDFC Bank SMS Tests
    
    func testHDFCBankUPIDebit() {
        let sms = "HDFC Bank: Rs 520.00 debited from a/c **4321 on 25-AUG-26 to VPA swiggy@upi (UPI Ref no 482019283741). Avl bal: Rs 15,400.00"
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(520.00))
        XCTAssertEqual(parsed?.currencyCode, "INR")
        XCTAssertEqual(parsed?.direction, .expense)
        XCTAssertEqual(parsed?.bankName, "HDFC Bank")
        XCTAssertEqual(parsed?.accountMask, "4321")
        XCTAssertEqual(parsed?.upiVPA, "swiggy@upi")
        XCTAssertEqual(parsed?.referenceNumber, "482019283741")
        XCTAssertEqual(parsed?.availableBalance, Decimal(15400.00))
        XCTAssertTrue(parsed?.merchant.localizedCaseInsensitiveContains("Swiggy") == true)
    }
    
    func testHDFCCreditCardSpend() {
        let sms = "Alert: Rs. 2,499.00 spent on HDFC Bank Card ending 9876 at AMAZON INDIA on 25-AUG-26. Avl limit: Rs 1,45,000.00"
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(2499.00))
        XCTAssertEqual(parsed?.direction, .expense)
        XCTAssertEqual(parsed?.bankName, "HDFC Bank")
        XCTAssertEqual(parsed?.accountMask, "9876")
        XCTAssertEqual(parsed?.availableBalance, Decimal(145000.00))
        XCTAssertTrue(parsed?.merchant.localizedCaseInsensitiveContains("Amazon") == true)
    }
    
    func testHDFCSalaryCredit() {
        let sms = "HDFC Bank: Rs 45,000.00 credited to a/c **4321 on 25-AUG-26 by SALARY / EMPLOYER. Avl bal: Rs 60,400.00"
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(45000.00))
        XCTAssertEqual(parsed?.direction, .income)
        XCTAssertEqual(parsed?.accountMask, "4321")
        XCTAssertEqual(parsed?.inferredCategory, "Salary")
    }
    
    // MARK: - ICICI Bank SMS Tests
    
    func testICICIBankUPIDebit() {
        let sms = "Dear Customer, ICICI Bank a/c XX1234 debited for INR 750.00 on 25-Aug-26. Info: UPI/482019283741/Swiggy. Available Balance is INR 22,340.00"
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(750.00))
        XCTAssertEqual(parsed?.bankName, "ICICI Bank")
        XCTAssertEqual(parsed?.accountMask, "1234")
        XCTAssertEqual(parsed?.availableBalance, Decimal(22340.00))
    }
    
    func testICICICardSpend() {
        let sms = "Tranx of INR 1,299.00 using ICICI Bank Card 5678 done at ZOMATO on 25-Aug-26. Avl Lmt: INR 88,000.00"
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(1299.00))
        XCTAssertEqual(parsed?.accountMask, "5678")
        XCTAssertTrue(parsed?.merchant.localizedCaseInsensitiveContains("Zomato") == true)
    }
    
    func testICICINEFTCredit() {
        let sms = "Dear Customer, your ICICI Bank Account XX1234 has been credited with INR 85,000.00 on 25-Aug-26 by NEFT-ACME CORP. Total Avail Bal INR 1,07,340.00"
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(85000.00))
        XCTAssertEqual(parsed?.direction, .income)
        XCTAssertEqual(parsed?.accountMask, "1234")
    }
    
    // MARK: - State Bank of India (SBI) SMS Tests
    
    func testSBIUPIDebit() {
        let sms = "Your A/C XXXXX123456 debited by Rs.1200.00 on 25Aug26 transfer to Zomato UPI/482019283741. (Avl Bal Rs:8,450.00) - SBI"
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(1200.00))
        XCTAssertEqual(parsed?.bankName, "State Bank of India")
        XCTAssertEqual(parsed?.direction, .expense)
        XCTAssertEqual(parsed?.availableBalance, Decimal(8450.00))
    }
    
    func testSBISalaryCredit() {
        let sms = "Your A/C XXXXX123456 credited by Rs.50000.00 on 25Aug26 by salary transfer. (Avl Bal Rs:58,450.00) - SBI"
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(50000.00))
        XCTAssertEqual(parsed?.direction, .income)
    }
    
    func testSBIATMCashWithdrawal() {
        let sms = "Your A/C XXXXX123456 debited by Rs.5000.00 on 25Aug26 at SBI ATM CASH WDL. Avl Bal Rs:3,450.00"
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(5000.00))
        XCTAssertEqual(parsed?.direction, .cashWithdrawal)
        XCTAssertEqual(parsed?.inferredCategory, "Cash")
    }
    
    // MARK: - Axis Bank SMS Tests
    
    func testAxisBankUPIDebit() {
        let sms = "INR 650.00 debited from Axis Bank A/C no. XX9876 on 25-08-2026 to BLINKIT via UPI. Avail Bal: INR 12,300.00"
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(650.00))
        XCTAssertEqual(parsed?.bankName, "Axis Bank")
        XCTAssertEqual(parsed?.accountMask, "9876")
        XCTAssertTrue(parsed?.merchant.localizedCaseInsensitiveContains("Blinkit") == true)
    }
    
    func testAxisBankCardSpend() {
        let sms = "Spent Rs. 3200 on Axis Bank Credit Card ending 4321 at RELIANCE DIGITAL on 25-Aug-26. Available limit: Rs. 95,000"
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(3200.00))
        XCTAssertEqual(parsed?.accountMask, "4321")
        XCTAssertTrue(parsed?.merchant.localizedCaseInsensitiveContains("Reliance") == true)
    }
    
    // MARK: - Kotak Mahindra Bank SMS Tests
    
    func testKotakBankSentMoney() {
        let sms = "Sent Rs. 350.00 from Kotak Bank A/C XX3456 to Dunzo on 25-08-26. Ref no 482019283741. Bal: Rs 4,500.00"
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(350.00))
        XCTAssertEqual(parsed?.bankName, "Kotak Mahindra Bank")
        XCTAssertEqual(parsed?.accountMask, "3456")
        XCTAssertTrue(parsed?.merchant.localizedCaseInsensitiveContains("Dunzo") == true)
    }
    
    func testKotakBankReceivedMoney() {
        let sms = "Kotak Bank: Rs 1000.00 credited to A/C XX3456 on 25-08-26 from John Doe."
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(1000.00))
        XCTAssertEqual(parsed?.direction, .income)
    }
    
    // MARK: - American Express & Standard Chartered Tests
    
    func testAmexCardSpend() {
        let sms = "Approved: INR 4,800.00 spent on your American Express Card ending 1004 at APPLE STORE on 25-Aug-26."
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(4800.00))
        XCTAssertEqual(parsed?.bankName, "American Express")
        XCTAssertEqual(parsed?.accountMask, "1004")
    }
    
    func testStandardCharteredCardSpend() {
        let sms = "Your Standard Chartered Card ending 7890 was used for INR 899.00 at UBER on 25-Aug-26."
        let parsed = BankSMSParser.parse(smsText: sms)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.amount, Decimal(899.00))
        XCTAssertEqual(parsed?.bankName, "Standard Chartered")
        XCTAssertEqual(parsed?.accountMask, "7890")
    }
}
