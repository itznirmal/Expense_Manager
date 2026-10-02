//
//  WidgetSharedModels.swift
//  ExpenseManagerWidgets
//
//  Minimal shared snapshot types for the widget extension target.
//  (Duplicated lightly so the widget target does not depend on the full app module.)
//

import Foundation

struct WidgetFinanceSnapshot: Codable, Equatable {
    var monthExpense: Decimal
    var monthIncome: Decimal
    var remainingBudget: Decimal
    var dailyAllowance: Decimal
    var currencyCode: String
    var pendingReviewCount: Int
    var updatedAt: Date

    init(
        monthExpense: Decimal = .zero,
        monthIncome: Decimal = .zero,
        remainingBudget: Decimal = .zero,
        dailyAllowance: Decimal = .zero,
        currencyCode: String = "INR",
        pendingReviewCount: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.monthExpense = monthExpense
        self.monthIncome = monthIncome
        self.remainingBudget = remainingBudget
        self.dailyAllowance = dailyAllowance
        self.currencyCode = currencyCode
        self.pendingReviewCount = pendingReviewCount
        self.updatedAt = updatedAt
    }
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.nirmal.ExpenseManager"
    private static let snapshotKey = "widgetFinanceSnapshot"
    static var showsAmounts: Bool {
        UserDefaults(suiteName: appGroupID)?.bool(forKey: "widgetShowsAmounts") ?? false
    }

    static func load() -> WidgetFinanceSnapshot {
        guard showsAmounts, let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetFinanceSnapshot.self, from: data) else {
            return WidgetFinanceSnapshot()
        }
        return snapshot
    }
}
