//
//  MerchantNormalizer.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Merchant Entity Resolution, Noise Stripping, and Categorization Knowledge.
//

import Foundation

/// Resolved merchant information with standardized name and inferred category.
public struct ExtractedMerchant: Equatable, Sendable {
    public let normalizedName: String
    public let rawName: String
    public let inferredCategory: String?
    
    public init(
        normalizedName: String,
        rawName: String,
        inferredCategory: String? = nil
    ) {
        self.normalizedName = normalizedName
        self.rawName = rawName
        self.inferredCategory = inferredCategory
    }
}

/// Normalizes raw merchant strings, strips transaction noise prefixes/suffixes, and infers default categories.
public struct MerchantNormalizer: Sendable {
    
    public init() {}
    
    // Noise patterns to strip from merchant strings
    private static let noisePrefixRegex = "(?i)^(?:vpa\\*?|upi[/\\*]?|pos[/\\*]?|txn[/\\*]?|info\\*|payment\\s+to\\s+|sent\\s+to\\s+|paid\\s+to\\s+|purchase\\s+(?:at|on)\\s+|spent\\s+at\\s+|billdesk\\*|razorpay\\*|paytm\\*|cc\\*|direct\\s+debit\\s+|ref[/\\*]?)\\s*"
    
    private static let noiseSuffixRegex = "(?i)\\s*(?:(?:pvt\\.?\\s+ltd\\.?)|(?:private\\s+limited)|(?:ltd\\.?)|(?:limited)|(?:llp\\.?)|(?:inc\\.?)|(?:corp\\.?)|(?:co\\.?)|(?:india\\s+pvt\\s+ltd)|(?:india\\s+private\\s+limited)|(?:india\\s+technology)|(?:india\\s+technologies)|(?:india)|(?:technology)|(?:technologies)|(?:services)|(?:entertainment)|(?:commerce)|(?:retail)|(?:quick\\s+commerce)|(?:petrol\\s+pump))\\b"
    
    private static let locationNoiseRegex = "(?i)\\*(?:bangalore|mumbai|delhi|gurgaon|hyderabad|pune|chennai|noida|kolkata|ahmedabad|india)\\b"
    
    // Known merchant canonical lookup
    private static let knownMerchants: [String: (name: String, category: String)] = [
        "swiggy": ("Swiggy", "Food & Dining"),
        "zomato": ("Zomato", "Food & Dining"),
        "uber": ("Uber", "Transportation"),
        "ola": ("Ola", "Transportation"),
        "rapido": ("Rapido", "Transportation"),
        "amazon": ("Amazon", "Shopping"),
        "flipkart": ("Flipkart", "Shopping"),
        "myntra": ("Myntra", "Shopping"),
        "starbucks": ("Starbucks", "Food & Dining"),
        "mcdonalds": ("McDonald's", "Food & Dining"),
        "mcdonald's": ("McDonald's", "Food & Dining"),
        "dominos": ("Domino's Pizza", "Food & Dining"),
        "domino's": ("Domino's Pizza", "Food & Dining"),
        "kfc": ("KFC", "Food & Dining"),
        "netflix": ("Netflix", "Entertainment"),
        "spotify": ("Spotify", "Entertainment"),
        "apple": ("Apple", "Subscriptions"),
        "google": ("Google", "Subscriptions"),
        "youtube": ("YouTube", "Entertainment"),
        "blinkit": ("Blinkit", "Groceries"),
        "zepto": ("Zepto", "Groceries"),
        "instamart": ("Swiggy Instamart", "Groceries"),
        "bigbasket": ("BigBasket", "Groceries"),
        "bbnow": ("BigBasket Now", "Groceries"),
        "dunzo": ("Dunzo", "Groceries"),
        "shell": ("Shell", "Fuel"),
        "hp petrol": ("HP Fuel", "Fuel"),
        "hpcl": ("HP Fuel", "Fuel"),
        "bpcl": ("BP Fuel", "Fuel"),
        "ioc": ("Indian Oil", "Fuel"),
        "indianoil": ("Indian Oil", "Fuel"),
        "airtel": ("Airtel", "Bills & Utilities"),
        "jio": ("Jio", "Bills & Utilities"),
        "vodafone": ("Vi", "Bills & Utilities"),
        "vi": ("Vi", "Bills & Utilities"),
        "makemytrip": ("MakeMyTrip", "Travel"),
        "mmt": ("MakeMyTrip", "Travel"),
        "bookmyshow": ("BookMyShow", "Entertainment"),
        "bms": ("BookMyShow", "Entertainment"),
        "apollo": ("Apollo Pharmacy", "Healthcare"),
        "apollo pharmacy": ("Apollo Pharmacy", "Healthcare"),
        "medplus": ("MedPlus", "Healthcare"),
        "pharmeasy": ("PharmEasy", "Healthcare"),
        "1mg": ("Tata 1mg", "Healthcare"),
        "decathlon": ("Decathlon", "Sports & Fitness"),
        "cultfit": ("Cult.fit", "Health & Fitness"),
        "curefit": ("Cult.fit", "Health & Fitness"),
        "indigo": ("IndiGo", "Travel"),
        "air india": ("Air India", "Travel"),
        "irctc": ("IRCTC", "Travel"),
        "uber india": ("Uber", "Transportation"),
        "amazon pay": ("Amazon", "Shopping"),
        "flipkart internet": ("Flipkart", "Shopping"),
        "starbucks coffee": ("Starbucks", "Food & Dining"),
        "blinkit commerce": ("Blinkit", "Groceries"),
        "zepto quick": ("Zepto", "Groceries"),
        "shell fuel": ("Shell", "Fuel"),
        "shell petrol": ("Shell", "Fuel")
    ]
    
    /// Cleans and normalizes a candidate merchant string.
    public static func normalizeMerchantName(_ raw: String) -> ExtractedMerchant {
        var cleaned = InputNormalizer.normalize(raw)
        guard !cleaned.isEmpty else {
            return ExtractedMerchant(normalizedName: "Unknown Merchant", rawName: raw)
        }
        
        // 1. Remove noise prefixes
        cleaned = cleaned.replacingOccurrences(of: noisePrefixRegex, with: "", options: .regularExpression)
        
        // 2. Remove location noise (*BANGALORE, *MUMBAI)
        cleaned = cleaned.replacingOccurrences(of: locationNoiseRegex, with: "", options: .regularExpression)
        
        // 3. Remove legal entity noise suffixes
        cleaned = cleaned.replacingOccurrences(of: noiseSuffixRegex, with: "", options: .regularExpression)
        
        // 4. Clean stray asterisks, slashes, hyphens, and whitespace
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: " *-_/#@\t\n\r"))
        
        guard !cleaned.isEmpty else {
            return ExtractedMerchant(normalizedName: "Unknown Merchant", rawName: raw)
        }
        
        // 5. Match against known merchant directory
        let key = cleaned.lowercased()
        
        // Exact match
        if let match = knownMerchants[key] {
            return ExtractedMerchant(normalizedName: match.name, rawName: raw, inferredCategory: match.category)
        }
        
        // Substring match for known merchants (e.g. "SWIGGY*BANGALORE" -> key "swiggy")
        for (pattern, match) in knownMerchants {
            if key.contains(pattern) {
                return ExtractedMerchant(normalizedName: match.name, rawName: raw, inferredCategory: match.category)
            }
        }
        
        // 6. Title case fallback
        let titleCased = cleaned.capitalized
        return ExtractedMerchant(normalizedName: titleCased, rawName: raw, inferredCategory: nil)
    }
}
