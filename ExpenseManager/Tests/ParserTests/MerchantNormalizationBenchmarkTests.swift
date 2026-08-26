//
//  MerchantNormalizationBenchmarkTests.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//

import XCTest
@testable import ExpenseManager

final class MerchantNormalizationBenchmarkTests: XCTestCase {
    
    func testMerchantNormalization() {
        let fixtures: [(raw: String, expected: String)] = [
            ("VPA*swiggy@hdfcbank", "Swiggy"),
            ("UPI/Zomato/123456", "Zomato"),
            ("POS*BLINKIT INDIA PVT LTD", "Blinkit"),
            ("E-COM*AMAZON PAY INDIA", "Amazon"),
            ("TXN*Zepto Quick Commerce", "Zepto"),
            ("INFO*Starbucks Coffee", "Starbucks"),
            ("Payment to NETFLIX ENTERTAINMENT", "Netflix"),
            ("Spent at D-MART BANGALORE", "D-Mart"),
            ("Paid to UBER INDIA SYSTEMS", "Uber"),
            ("Purchase at OLA TECHNOLOGIES", "Ola"),
            ("IRCTC NEW DELHI", "IRCTC"),
            ("MAKE MY TRIP INDIA PVT LTD", "MakeMyTrip"),
            ("INDIGO AIRLINES", "IndiGo"),
            ("FLIPKART INTERNET PVT", "Flipkart"),
            ("MYNTRA DESIGNS", "Myntra"),
            ("NYKAA E-RETAIL", "Nykaa"),
            ("AJIO RETAIL LIMITED", "Ajio"),
            ("TATA NEU BANGALORE", "Tata Neu"),
            ("DECATHLON SPORTS INDIA", "Decathlon"),
            ("SPOTIFY AB", "Spotify"),
            ("BOOKMYSHOW MUMBAI", "BookMyShow"),
            ("AIRTEL PAYMENT", "Airtel"),
            ("JIO INFOCOMM", "Jio"),
            ("BESCOM BANGALORE", "BESCOM"),
            ("TATA POWER MUMBAI", "Tata Power"),
            ("SWIGGY INSTAMART", "Swiggy Instamart")
        ]
        
        for fixture in fixtures {
            let extracted = MerchantNormalizer.normalizeMerchantName(fixture.raw)
            XCTAssertEqual(extracted.normalizedName, fixture.expected, "Failed for \(fixture.raw)")
        }
    }
    
    func testVPANoiseStripping() {
        let vpas = [
            "swiggy.payu@okhdfcbank",
            "zomato@okaxis",
            "blinkit@oksbi",
            "zepto@paytm",
            "uber@apl"
        ]
        
        let expected = ["Swiggy", "Zomato", "Blinkit", "Zepto", "Uber"]
        
        for (index, raw) in vpas.enumerated() {
            let extracted = MerchantNormalizer.normalizeMerchantName(raw)
            XCTAssertEqual(extracted.normalizedName, expected[index], "Failed VPA stripping for \(raw)")
        }
    }
}
