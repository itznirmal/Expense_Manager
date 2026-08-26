//
//  BankSMSParser.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Deterministic Multi-Bank SMS Parser for Top Indian Banks & RBI Standard SMS Formats.
//

import Foundation

/// Structured transaction payload extracted from Indian Bank SMS messages.
public struct BankParsedResult: Equatable, Sendable {
    public var amount: Decimal
    public var currencyCode: String
    public var direction: TransactionType
    public var merchant: String
    public var bankName: String?
    public var accountMask: String?
    public var paymentMethod: PaymentMethod?
    public var referenceNumber: String?
    public var upiVPA: String?
    public var date: Date
    public var inferredCategory: String?
    public var availableBalance: Decimal?
    public var rawSMS: String
    
    public init(
        amount: Decimal,
        currencyCode: String = CurrencyFormatter.defaultCurrencyCode,
        direction: TransactionType = .expense,
        merchant: String,
        bankName: String? = nil,
        accountMask: String? = nil,
        paymentMethod: PaymentMethod? = nil,
        referenceNumber: String? = nil,
        upiVPA: String? = nil,
        date: Date = Date(),
        inferredCategory: String? = nil,
        availableBalance: Decimal? = nil,
        rawSMS: String = ""
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.direction = direction
        self.merchant = merchant
        self.bankName = bankName
        self.accountMask = accountMask
        self.paymentMethod = paymentMethod
        self.referenceNumber = referenceNumber
        self.upiVPA = upiVPA
        self.date = date
        self.inferredCategory = inferredCategory
        self.availableBalance = availableBalance
        self.rawSMS = rawSMS
    }
}

/// Multi-Bank deterministic SMS parser tailored for Indian financial institutions.
public struct BankSMSParser: Sendable {
    
    public init() {}
    
    /// Parses an incoming bank SMS into structured fields.
    public static func parse(smsText: String, referenceDate: Date = Date()) -> BankParsedResult? {
        let cleaned = InputNormalizer.normalize(smsText)
        guard !cleaned.isEmpty else { return nil }
        
        // 1. Identify Bank Identifier
        let bankName = identifyBank(from: cleaned)
        
        // 2. Identify Direction
        let direction = TransactionDirectionClassifier.classify(text: cleaned).type
        
        // 3. Extract Available Balance (so it is not mistaken for transaction amount)
        let (extractedBalance, textWithoutBalance) = extractAvailableBalance(from: cleaned)
        
        // 4. Extract Primary Transaction Amount
        guard let amountData = AmountParser.extractAmount(from: textWithoutBalance), amountData.amount > .zero else {
            return nil
        }
        let amount = amountData.amount
        let currencyCode = amountData.currencyCode
        
        // 5. Extract Account Mask / Card Ending
        let accountData = AccountHintParser.extractAccountHint(from: cleaned)
        let accountMask = accountData?.accountLastFour
        var paymentMethod = accountData?.paymentMethod
        
        // 6. Extract Reference & UPI VPA
        let refData = ReferenceNumberParser.extractReference(from: cleaned)
        let referenceNumber = refData?.referenceNumber
        let upiVPA = refData?.upiVPA
        
        if paymentMethod == nil && upiVPA != nil {
            paymentMethod = .upi
        }
        
        // 7. Extract Transaction Date
        let dateData = DateParser.extractDate(from: cleaned, referenceDate: referenceDate)
        let transactionDate = dateData?.date ?? referenceDate
        
        // 8. Extract Merchant Name using bank-specific rules or generic residual tokenization
        let merchant = extractMerchant(
            smsText: cleaned,
            bankName: bankName,
            direction: direction,
            upiVPA: upiVPA
        )
        
        // 9. Infer Category from merchant name
        let merchantNormalized = MerchantNormalizer.normalizeMerchantName(merchant)
        var inferredCategory = merchantNormalized.inferredCategory
        
        if inferredCategory == nil {
            if direction == .income {
                inferredCategory = "Salary"
            } else if direction == .cashWithdrawal {
                inferredCategory = "Cash"
            } else if direction == .transfer {
                inferredCategory = "Transfer"
            } else if direction == .refund {
                inferredCategory = "Refunds"
            }
        }
        
        return BankParsedResult(
            amount: amount,
            currencyCode: currencyCode,
            direction: direction,
            merchant: merchantNormalized.normalizedName.isEmpty ? merchant : merchantNormalized.normalizedName,
            bankName: bankName ?? accountData?.accountSuggestion,
            accountMask: accountMask,
            paymentMethod: paymentMethod,
            referenceNumber: referenceNumber,
            upiVPA: upiVPA,
            date: transactionDate,
            inferredCategory: inferredCategory,
            availableBalance: extractedBalance,
            rawSMS: cleaned
        )
    }
    
    // MARK: - Bank Identification
    
    public static func identifyBank(from text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("hdfc") { return "HDFC Bank" }
        if lower.contains("icici") { return "ICICI Bank" }
        if lower.contains("sbi") || lower.contains("state bank") { return "State Bank of India" }
        if lower.contains("axis") { return "Axis Bank" }
        if lower.contains("kotak") { return "Kotak Mahindra Bank" }
        if lower.contains("amex") || lower.contains("american express") { return "American Express" }
        if lower.contains("scb") || lower.contains("standard chartered") { return "Standard Chartered" }
        if lower.contains("pnb") || lower.contains("punjab national") { return "Punjab National Bank" }
        if lower.contains("indusind") { return "IndusInd Bank" }
        if lower.contains("yes bank") { return "Yes Bank" }
        if lower.contains("idfc") { return "IDFC FIRST Bank" }
        if lower.contains("canara") { return "Canara Bank" }
        if lower.contains("union bank") { return "Union Bank of India" }
        if lower.contains("bank of baroda") || lower.contains("bob") { return "Bank of Baroda" }
        return nil
    }
    
    // MARK: - Available Balance Extraction
    
    private static func extractAvailableBalance(from text: String) -> (balance: Decimal?, cleanedText: String) {
        let pattern = "(?i)\\b(?:avl\\s*bal|avail\\s*bal|available\\s*balance|avail\\s*limit|avl\\s*lmt|total\\s*avail\\s*bal)\\s*(?:is|:)?\\s*(?:rs\\.?|inr|₹)?\\s*([0-9,]+(?:\\.[0-9]{1,2})?)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (nil, text)
        }
        
        let nsString = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsString.length)) else {
            return (nil, text)
        }
        
        var balance: Decimal? = nil
        if match.numberOfRanges > 1 {
            let balanceString = nsString.substring(with: match.range(at: 1))
            balance = CurrencyFormatter.shared.parse(from: balanceString)
        }
        
        // Return cleaned text without the balance substring to prevent AmountParser conflict
        let cleaned = nsString.replacingCharacters(in: match.range, with: "")
        return (balance, cleaned)
    }
    
    // MARK: - Merchant Extraction
    
    private static func extractMerchant(
        smsText: String,
        bankName: String?,
        direction: TransactionType,
        upiVPA: String?
    ) -> String {
        // Special case: ATM cash withdrawal
        if direction == .cashWithdrawal || smsText.localizedCaseInsensitiveContains("atm") {
            return "ATM Cash Withdrawal"
        }
        
        // 1. Check for specific merchant markers like 'to VPA ...', 'to ...', 'at ...', 'info: ...'
        let merchantPatterns = [
            // "to VPA swiggy@upi"
            "(?i)\\b(?:to\\s+vpa|to\\s+upi\\s+id|vpa)\\s+([a-zA-Z0-9._-]+@[a-zA-Z0-9]+)",
            // "at AMAZON INDIA on"
            "(?i)\\b(?:at|spent\\s+at|purchase\\s+at)\\s+([A-Za-z0-9&.,\\s'-]{2,30}?)(?:\\s+on\\s+|\\s+via\\s+|\\s+using\\s+|\\s*\\.|\\s*\\,|$)",
            // "to BLINKIT on / to John Doe on"
            "(?i)\\b(?:to|sent\\s+to|transfer\\s+to|paid\\s+to)\\s+([A-Za-z0-9&.,\\s'-]{2,30}?)(?:\\s+on\\s+|\\s+via\\s+|\\s+using\\s+|\\s*\\.|\\s*\\,|$)",
            // "Info: UPI/482019283741/Swiggy"
            "(?i)\\b(?:info|inf):?\\s*(?:upi\\/[0-9]+\\/)?([A-Za-z0-9&.,\\s'-]{2,30}?)(?:\\s+on|\\s*\\.|\\s*\\,|$)",
            // "credited by SALARY / EMPLOYER"
            "(?i)\\b(?:credited\\s+by|from|received\\s+from)\\s+([A-Za-z0-9&.,\\s'-]{2,30}?)(?:\\s+on\\s+|\\s+via\\s+|\\s*\\.|\\s*\\,|$)"
        ]
        
        for pattern in merchantPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsString = smsText as NSString
                if let match = regex.firstMatch(in: smsText, range: NSRange(location: 0, length: nsString.length)),
                   match.numberOfRanges > 1 {
                    let rawExtracted = nsString.substring(with: match.range(at: 1))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !rawExtracted.isEmpty && !rawExtracted.localizedCaseInsensitiveContains("hdfc") && !rawExtracted.localizedCaseInsensitiveContains("icici") && !rawExtracted.localizedCaseInsensitiveContains("axis") && !rawExtracted.localizedCaseInsensitiveContains("kotak") && !rawExtracted.localizedCaseInsensitiveContains("sbi") {
                        return cleanMerchantString(rawExtracted)
                    }
                }
            }
        }
        
        // 2. If UPI VPA exists, derive from VPA handle
        if let vpa = upiVPA {
            let handle = vpa.components(separatedBy: "@").first ?? ""
            if !handle.isEmpty {
                return cleanMerchantString(handle)
            }
        }
        
        // 3. Fallback to direction-based meaningful label
        switch direction {
        case .income: return "Salary / Deposit"
        case .refund: return "Refund"
        case .transfer: return "Account Transfer"
        case .cashWithdrawal: return "ATM Cash Withdrawal"
        case .expense, .unknown: return bankName != nil ? "\(bankName!) Expense" : "Card / Bank Expense"
        }
    }
    
    private static func cleanMerchantString(_ raw: String) -> String {
        var text = raw
        let unwanted = [
            "(?i)\\b(?:vpa|upi|ref|no|txn|pvt|ltd|limited|corp|bank|card|ending|avl|bal|inr|rs)\\b",
            "[\\*\\#\\(\\)\\[\\]\\:\\;\\/]"
        ]
        for pattern in unwanted {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Merchant" : trimmed.capitalized
    }
}
