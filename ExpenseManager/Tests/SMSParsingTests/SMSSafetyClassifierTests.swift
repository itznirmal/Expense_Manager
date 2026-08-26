//
//  SMSSafetyClassifierTests.swift
//  ExpenseManagerTests
//
//  Created for Expense Manager iOS.
//  Strict Unit Tests verifying AC-PARSE-2 (Rejection of Non-Transaction Messages).
//

import XCTest
@testable import ExpenseManager

final class SMSSafetyClassifierTests: XCTestCase {
    
    // MARK: - OTP & Verification Code Tests (Must NEVER create a transaction)
    
    func testOTPMessagesAreStrictlyRejected() {
        let otpMessages = [
            "Your OTP for login to HDFC NetBanking is 492019. Valid for 10 minutes. Do not share with anyone.",
            "839201 is your secret OTP for transaction of Rs. 1,500.00 at Amazon India. Never share OTP with anyone.",
            "Dear Customer, 582910 is your One Time Password (OTP) for authenticating your ICICI card payment.",
            "Use verification code 492019 for your Apple ID authentication. Valid till 10 mins.",
            "Your SBI UPI registration OTP is 192834. Do not disclose to anyone including bank officials.",
            "Axis Bank: 749201 is your OTP to approve transaction of INR 3,450.00 on card ending 9876."
        ]
        
        for msg in otpMessages {
            let result = SMSSafetyClassifier.classify(text: msg)
            XCTAssertFalse(
                result.isSafeForTransactionGeneration,
                "OTP message must be rejected from transaction creation: \(msg)"
            )
            XCTAssertEqual(result.messageType, .otp, "Expected message type .otp for: \(msg)")
            XCTAssertNotNil(result.rejectionReason)
        }
    }
    
    // MARK: - Failed & Declined Transactions Tests (Must NEVER create a transaction)
    
    func testDeclinedAndFailedTransactionsAreStrictlyRejected() {
        let declinedMessages = [
            "Transaction of Rs. 2,400.00 on HDFC Bank Card 9876 was declined due to insufficient balance.",
            "Dear Customer, your transaction of INR 1,200.00 at ZOMATO got declined. Daily limit exceeded.",
            "Your payment of Rs 450 to Swiggy failed. Amount not debited from your account.",
            "SBI: Payment of Rs. 5,000.00 could not be processed. Txn failed. Please retry.",
            "Axis Bank: Transaction declined for INR 15,000.00 on Card ending 4321 due to insufficient funds.",
            "Transaction unsuccessful: Rs 890.00 on Kotak Bank A/C XX3456. Reason: Bank server busy."
        ]
        
        for msg in declinedMessages {
            let result = SMSSafetyClassifier.classify(text: msg)
            XCTAssertFalse(
                result.isSafeForTransactionGeneration,
                "Declined or failed payment must be rejected: \(msg)"
            )
            XCTAssertTrue(
                result.messageType == .declinedTransaction || result.messageType == .failedTransaction,
                "Expected failed or declined type for: \(msg)"
            )
        }
    }
    
    // MARK: - Card Blocked & Security Alerts Tests
    
    func testCardBlockedAndSecurityAlertsAreRejected() {
        let securityMessages = [
            "Your HDFC Bank Debit Card ending 4321 has been temporarily blocked due to suspicious activity.",
            "Alert: We detected unauthorized login attempt. Your card is locked to prevent misuse.",
            "Security Notice: Your SBI card ending 9876 has been blocked permanently as requested.",
            "Axis Bank fraud alert: Card XX1234 deactivated due to suspicious transaction attempt."
        ]
        
        for msg in securityMessages {
            let result = SMSSafetyClassifier.classify(text: msg)
            XCTAssertFalse(
                result.isSafeForTransactionGeneration,
                "Security alert must be rejected: \(msg)"
            )
            XCTAssertEqual(result.messageType, .cardBlocked, "Expected .cardBlocked for: \(msg)")
        }
    }
    
    // MARK: - Marketing & Promotional Ads Tests
    
    func testMarketingSpamIsStrictlyRejected() {
        let promoMessages = [
            "Congratulations! You are eligible for a pre-approved personal loan of Rs 5,00,000 at zero interest. Apply now.",
            "Get 50% cashback on your next movie booking on BookMyShow. Use code MOVIE50.",
            "Upgrade your HDFC Credit Card and get Rs 2,000 voucher. Click here to apply.",
            "Instant personal loan up to Rs. 10 Lakhs approved for you. Zero documentation. Apply today!",
            "Special offer: Flat 20% discount on flight tickets with ICICI Bank Credit Cards."
        ]
        
        for msg in promoMessages {
            let result = SMSSafetyClassifier.classify(text: msg)
            XCTAssertFalse(
                result.isSafeForTransactionGeneration,
                "Marketing spam must be rejected: \(msg)"
            )
            XCTAssertEqual(result.messageType, .spamMarketing, "Expected .spamMarketing for: \(msg)")
        }
    }
    
    // MARK: - Bill Due Reminders & Balance Queries Tests
    
    func testBillDueRemindersAndBalanceQueriesAreRejected() {
        let nonTxnMessages = [
            "Your ICICI Credit Card statement for Aug is generated. Total amount due: Rs 14,500.00. Due date: 10-Sep-26.",
            "Minimum amount due for HDFC Card ending 9876 is Rs. 750.00. Pay before 05-Sep to avoid late fee.",
            "Available balance in your A/C XX4321 is Rs. 45,210.50 as of 25-Aug-26.",
            "Dear Customer, current balance for A/C ending 1234 is INR 12,400.00. - SBI"
        ]
        
        for msg in nonTxnMessages {
            let result = SMSSafetyClassifier.classify(text: msg)
            XCTAssertFalse(
                result.isSafeForTransactionGeneration,
                "Bill reminder or balance query must be rejected: \(msg)"
            )
            XCTAssertTrue(
                result.messageType == .billDueReminder || result.messageType == .balanceAlert,
                "Expected bill reminder or balance alert for: \(msg)"
            )
        }
    }
    
    // MARK: - Valid Financial Debit & Credit Pass Tests
    
    func testValidTransactionsPassSafetyClassifier() {
        let validMessages: [(text: String, expectedType: SMSMessageType)] = [
            ("HDFC Bank: Rs 520.00 debited from a/c **4321 on 25-AUG-26 to VPA swiggy@upi.", .transactionalDebit),
            ("Spent Rs. 2,499.00 on HDFC Bank Card ending 9876 at AMAZON INDIA on 25-AUG-26.", .transactionalDebit),
            ("Dear Customer, ICICI Bank a/c XX1234 debited for INR 750.00 on 25-Aug-26 to Zomato.", .transactionalDebit),
            ("Your A/C XXXXX123456 debited by Rs.1200.00 on 25Aug26 transfer to Blinkit.", .transactionalDebit),
            ("Your A/C XXXXX123456 credited by Rs.50000.00 on 25Aug26 by salary transfer.", .transactionalCredit),
            ("HDFC Bank: Rs 45,000.00 credited to a/c **4321 on 25-AUG-26 by SALARY.", .transactionalCredit),
            ("Kotak Bank: Rs 1000.00 credited to A/C XX3456 on 25-08-26 from John Doe.", .transactionalCredit),
            ("INR 650.00 debited from Axis Bank A/C no. XX9876 on 25-08-2026 to BLINKIT.", .transactionalDebit)
        ]
        
        for item in validMessages {
            let result = SMSSafetyClassifier.classify(text: item.text)
            XCTAssertTrue(
                result.isSafeForTransactionGeneration,
                "Valid transaction must be approved: \(item.text)"
            )
            XCTAssertEqual(result.messageType, item.expectedType, "Type mismatch for: \(item.text)")
            XCTAssertNil(result.rejectionReason)
        }
    }
}
