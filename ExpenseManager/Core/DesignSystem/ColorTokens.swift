//
//  ColorTokens.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Semantic Color System & Apple HIG Dark/Light Tokens.
//

import SwiftUI

/// Semantic Color Tokens conforming to Apple Human Interface Guidelines.
/// Automatically responds to Light and Dark mode appearances.
public enum ColorTokens {
    
    // MARK: - Surfaces & Backgrounds
    
    /// Primary canvas background
    public static var backgroundPrimary: Color {
        Color(uiColor: .systemGroupedBackground)
    }
    
    /// Secondary container/layer background
    public static var backgroundSecondary: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }
    
    /// Tertiary grouped background for inset elements
    public static var backgroundTertiary: Color {
        Color(uiColor: .tertiarySystemGroupedBackground)
    }
    
    /// Standard card surface background
    public static var cardBackground: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }
    
    /// Elevated modal and sheet background
    public static var elevatedBackground: Color {
        Color(uiColor: .systemBackground)
    }
    
    // MARK: - Text & Foreground
    
    /// Primary high-contrast text
    public static var textPrimary: Color {
        Color(uiColor: .label)
    }
    
    /// Secondary descriptive text
    public static var textSecondary: Color {
        Color(uiColor: .secondaryLabel)
    }
    
    /// Tertiary subtle placeholder / caption text
    public static var textTertiary: Color {
        Color(uiColor: .tertiaryLabel)
    }
    
    /// Disabled or unobtrusive icons and glyphs
    public static var textQuaternary: Color {
        Color(uiColor: .quaternaryLabel)
    }
    
    // MARK: - Financial Semantics
    
    /// Accent color for Expense transactions (Coral Red / Crimson)
    public static let expenseAccent = Color(red: 0.92, green: 0.26, blue: 0.28)
    
    /// Accent color for Income transactions (Mint Green / Emerald)
    public static let incomeAccent = Color(red: 0.18, green: 0.72, blue: 0.44)
    
    /// Accent color for Internal Account Transfers (Cobalt / Cyan)
    public static let transferAccent = Color(red: 0.00, green: 0.53, blue: 0.85)
    
    /// Accent color for Refunds (Violet / Amethyst)
    public static let refundAccent = Color(red: 0.58, green: 0.32, blue: 0.85)
    
    /// Warning / Budget Threshold Alert (Warm Amber)
    public static let warningAccent = Color(red: 0.95, green: 0.60, blue: 0.15)
    
    /// Critical Over-budget / Review Required Alert (Deep Red)
    public static let criticalAccent = Color(red: 0.88, green: 0.15, blue: 0.20)
    
    // MARK: - Brand & Accents
    
    /// Primary brand color (Indigo / Deep Blue)
    public static let brandPrimary = Color(red: 0.25, green: 0.35, blue: 0.85)
    
    /// Secondary brand tint
    public static let brandSecondary = Color(red: 0.38, green: 0.48, blue: 0.95)
    
    // MARK: - Borders & Separators
    
    /// Subtle divider separator
    public static var separator: Color {
        Color(uiColor: .separator)
    }
    
    /// Opaque subtle card border
    public static var borderSubtle: Color {
        Color(uiColor: .separator).opacity(0.4)
    }
    
    // MARK: - Category Palette Tokens
    
    public static let categoryPalette: [String: Color] = [
        "red": Color(red: 0.92, green: 0.26, blue: 0.28),
        "orange": Color(red: 0.95, green: 0.50, blue: 0.10),
        "yellow": Color(red: 0.95, green: 0.75, blue: 0.10),
        "green": Color(red: 0.18, green: 0.72, blue: 0.44),
        "teal": Color(red: 0.10, green: 0.70, blue: 0.75),
        "blue": Color(red: 0.15, green: 0.50, blue: 0.95),
        "indigo": Color(red: 0.35, green: 0.30, blue: 0.85),
        "purple": Color(red: 0.65, green: 0.30, blue: 0.85),
        "pink": Color(red: 0.92, green: 0.30, blue: 0.60),
        "gray": Color(red: 0.55, green: 0.55, blue: 0.60)
    ]
    
    public static func color(for token: String?) -> Color {
        guard let token = token?.lowercased(), let color = categoryPalette[token] else {
            return brandPrimary
        }
        return color
    }
}
