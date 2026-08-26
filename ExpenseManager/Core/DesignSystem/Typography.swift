//
//  Typography.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Dynamic Type Scale & Rounded Financial Typography Tokens.
//

import SwiftUI

/// Dynamic Type scale tokens conforming to Apple HIG.
/// Provides specialized rounded typography for monetary amounts and glanceable statistics.
public enum Typography {
    
    // MARK: - Display & Financial Amounts
    
    /// Hero financial amount on Dashboard (e.g. Total Net Balance)
    public static let amountHero: Font = .system(size: 34, weight: .bold, design: .rounded)
    
    /// Large monetary amounts (e.g. Account Cards, Budget Totals)
    public static let amountLarge: Font = .system(size: 28, weight: .bold, design: .rounded)
    
    /// Medium monetary amounts (e.g. Transaction Row Amounts)
    public static let amountMedium: Font = .system(size: 20, weight: .semibold, design: .rounded)
    
    /// Small monetary amounts (e.g. Sub-item badges, micro-charts)
    public static let amountSmall: Font = .system(size: 15, weight: .semibold, design: .rounded)
    
    // MARK: - Standard Dynamic Type Scale
    
    /// Large Title for Top-level Navigation views
    public static let largeTitle: Font = .largeTitle.weight(.bold)
    
    /// Primary section titles
    public static let title: Font = .title2.weight(.bold)
    
    /// Sub-section headers and modal titles
    public static let title3: Font = .title3.weight(.semibold)
    
    /// Card headers and transaction merchant titles
    public static let headline: Font = .headline
    
    /// Standard body content
    public static let body: Font = .body
    
    /// Emphasized callout texts
    public static let callout: Font = .callout
    
    /// Subhead / Category tag labels
    public static let subheadline: Font = .subheadline
    
    /// Secondary descriptive footnotes
    public static let footnote: Font = .footnote
    
    /// Timestamps and minor metadata
    public static let caption: Font = .caption
    
    /// Micro indicators and badges
    public static let caption2: Font = .caption2
}

// MARK: - View Modifiers & Helpers

public extension View {
    func financialAmountStyle(size: AmountSize = .medium, color: Color = ColorTokens.textPrimary) -> some View {
        self
            .font(size.font)
            .foregroundStyle(color)
            .monospacedDigit()
    }
}

public enum AmountSize {
    case hero
    case large
    case medium
    case small
    
    var font: Font {
        switch self {
        case .hero: return Typography.amountHero
        case .large: return Typography.amountLarge
        case .medium: return Typography.amountMedium
        case .small: return Typography.amountSmall
        }
    }
}
