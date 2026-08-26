//
//  IndianBankSMSCorpusTests.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//

import XCTest
@testable import ExpenseManager

final class IndianBankSMSCorpusTests: XCTestCase {
    
    func testPositiveDebitTransactions() {
        let debits = [
            "Rs.1500.00 debited from a/c **1234 on 15-08-24 to VPA swiggy@upi. Ref: 123456789. Avl Bal: Rs.50000.00 - HDFC Bank",
            "Txn of INR 550.00 done on Credit Card XX4567 at Zomato on 16-Aug-24. Avl Lmt: INR 150000. - ICICI Bank",
            "Dear Customer, Rs.999.00 has been debited from your A/c no. XXXXXX9876 on 10/10/24. Info: UPI/123/Blinkit. - SBI",
            "Paid Rs 2450.00 to AMAZON INDIA from A/c 5432 on 15-08-24. Avl Bal: Rs 10000.00. - Axis Bank",
            "Rs.350.00 spent on Kotak Credit Card ending 8888 at Starbucks on 16-08. Avl lmt Rs.80000.",
            "Debited Rs. 500.00 from a/c **1111 on 15-08-24 to VPA ola@upi. Ref: 111. Avl Bal: Rs.50000.00 - HDFC Bank",
            "Txn of INR 100.00 done on Credit Card XX4567 at Rapido on 16-Aug-24. Avl Lmt: INR 150000. - ICICI Bank",
            "Dear Customer, Rs.200.00 has been debited from your A/c no. XXXXXX9876 on 10/10/24. Info: UPI/123/Zepto. - SBI",
            "Paid Rs 2500.00 to Flipkart from A/c 5432 on 15-08-24. Avl Bal: Rs 10000.00. - Axis Bank",
            "Rs.300.00 spent on Kotak Credit Card ending 8888 at BookMyShow on 16-08. Avl lmt Rs.80000.",
            "Rs.120.00 debited from a/c **1234 on 15-08-24 to VPA blinkit@upi. Ref: 123456789. Avl Bal: Rs.50000.00 - Federal Bank",
            "Txn of INR 50.00 done on Credit Card XX4567 at Swiggy Instamart on 16-Aug-24. Avl Lmt: INR 150000. - Amex",
            "Dear Customer, Rs.499.00 has been debited from your A/c no. XXXXXX9876 on 10/10/24. Info: UPI/123/Netflix. - PNB",
            "Paid Rs 1450.00 to MakeMyTrip from A/c 5432 on 15-08-24. Avl Bal: Rs 10000.00. - Yes Bank",
            "Rs.150.00 spent on IndusInd Credit Card ending 8888 at Jio on 16-08. Avl lmt Rs.80000.",
            "Rs.10.00 debited from a/c **1234 on 15-08-24 to VPA paytm@upi. Ref: 123456789. Avl Bal: Rs.50000.00 - Standard Chartered",
            "Txn of INR 5000.00 done on Credit Card XX4567 at Decathlon on 16-Aug-24. Avl Lmt: INR 150000. - ICICI Bank",
            "Dear Customer, Rs.90.00 has been debited from your A/c no. XXXXXX9876 on 10/10/24. Info: UPI/123/Airtel. - Bank of Baroda",
            "Paid Rs 240.00 to BESCOM from A/c 5432 on 15-08-24. Avl Bal: Rs 10000.00. - Axis Bank",
            "Rs.1350.00 spent on Kotak Credit Card ending 8888 at Tata Neu on 16-08. Avl lmt Rs.80000."
        ]
        
        for sms in debits {
            let safety = SMSSafetyClassifier.classify(text: sms)
            XCTAssertTrue(safety.isSafeForTransactionGeneration, "Failed safety: \(sms)")
            
            let parsed = BankSMSParser.parse(smsText: sms)
            XCTAssertNotNil(parsed, "Failed parse: \(sms)")
            XCTAssertEqual(parsed?.direction, .expense)
            XCTAssertTrue((parsed?.amount ?? 0) > 0)
        }
    }
    
    func testPositiveCreditTransactions() {
        let credits = [
            "Rs.50000.00 credited to a/c **1234 on 01-08-24 from EMPLOYER. Avl Bal: Rs.55000.00 - HDFC Bank",
            "Salary of INR 45000.00 credited to A/c XX4567 on 31-Jul-24. - ICICI Bank",
            "Dear Customer, Rs.1000.00 has been credited to your A/c no. XXXXXX9876 on 10/10/24. - SBI",
            "Received Rs 2000.00 from John Doe in A/c 5432 on 15-08-24. Avl Bal: Rs 10000.00. - Axis Bank",
            "Refund of Rs.500.00 credited to Kotak Credit Card ending 8888.",
            "Rs.50.00 credited to a/c **1234 on 01-08-24 from Cashback. Avl Bal: Rs.55000.00 - HDFC Bank",
            "Refund of INR 450.00 credited to A/c XX4567 on 31-Jul-24. - ICICI Bank",
            "Dear Customer, Rs.10.00 has been credited to your A/c no. XXXXXX9876 on 10/10/24. - SBI",
            "Received Rs 20.00 from Jane Doe in A/c 5432 on 15-08-24. Avl Bal: Rs 10000.00. - Axis Bank",
            "Rs 100 credited to your account via UPI."
        ]
        
        for sms in credits {
            let safety = SMSSafetyClassifier.classify(text: sms)
            XCTAssertTrue(safety.isSafeForTransactionGeneration, "Failed safety: \(sms)")
            
            let parsed = BankSMSParser.parse(smsText: sms)
            XCTAssertNotNil(parsed, "Failed parse: \(sms)")
            XCTAssertEqual(parsed?.direction, .income)
        }
    }
    
    func testHardNegativeAlerts() {
        let negatives = [
            "Use OTP 123456 to verify your transaction of Rs.500. Do not share this OTP. - HDFC Bank",
            "Your Kotak Card ending 1234 has been temporarily blocked to prevent misuse.",
            "Txn of Rs.5000 declined at Zomato due to insufficient funds. - SBI",
            "Payment of Rs.400 failed at Swiggy. Amount not debited. - Axis",
            "Congratulations! You are pre-approved for a Personal Loan of Rs.500000. Apply now! - ICICI",
            "Your Credit Card bill of Rs.15000 is generated. Min amount due is Rs.1500. Pay before 20-Aug. - Amex",
            "Available balance in A/c **1234 is Rs.5000.00. - HDFC",
            "Dear Customer, your credit limit enhancement to Rs.200000 is ready.",
            "EMI of Rs.4500 is due on 05-Sep. Maintain sufficient balance.",
            "Your card is hotlisted successfully. Report immediately if not done by you.",
            "Use OTP 123456 for a transaction of Rs.100. - HDFC Bank",
            "Your Kotak Card ending 1234 has been blocked.",
            "Txn of Rs.50 declined at Zomato due to limit exceeded. - SBI",
            "Payment of Rs.40 failed at Swiggy. - Axis",
            "Your limit increased to Rs.500000. Apply now! - ICICI"
        ]
        
        for sms in negatives {
            let safety = SMSSafetyClassifier.classify(text: sms)
            XCTAssertFalse(safety.isSafeForTransactionGeneration, "Should have been rejected: \(sms)")
        }
    }
}
