//
//  WidgetSnapshotStore.swift
//  ExpenseManager
//
//  Shared App Group snapshot for home-screen widgets.
//

import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

/// Lightweight snapshot published for WidgetKit glance cards.
public struct WidgetFinanceSnapshot: Codable, Sendable, Equatable {
    public var monthExpense: Decimal
    public var monthIncome: Decimal
    public var remainingBudget: Decimal
    public var dailyAllowance: Decimal
    public var currencyCode: String
    public var pendingReviewCount: Int
    public var updatedAt: Date

    public init(
        monthExpense: Decimal = .zero,
        monthIncome: Decimal = .zero,
        remainingBudget: Decimal = .zero,
        dailyAllowance: Decimal = .zero,
        currencyCode: String = CurrencyFormatter.defaultCurrencyCode,
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

public enum WidgetSnapshotStore {
    public static let appGroupID = "group.com.nirmal.ExpenseManager"
    private static let snapshotKey = "widgetFinanceSnapshot"
    public static var showsAmounts: Bool {
        UserDefaults(suiteName: appGroupID)?.bool(forKey: "widgetShowsAmounts") ?? false
    }

    public static func setShowsAmounts(_ enabled: Bool) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(enabled, forKey: "widgetShowsAmounts")
        if !enabled { defaults.removeObject(forKey: snapshotKey) }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public static func save(_ snapshot: WidgetFinanceSnapshot) {
        guard !CommandLine.arguments.contains("-UITesting"), ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        if showsAmounts && !CurrencyFormatter.preferences.bool(forKey: "requireBiometrics") {
            defaults.set(data, forKey: snapshotKey)
        } else {
            defaults.removeObject(forKey: snapshotKey)
        }
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public static func load() -> WidgetFinanceSnapshot {
        guard showsAmounts, let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetFinanceSnapshot.self, from: data) else {
            return WidgetFinanceSnapshot()
        }
        return snapshot
    }
}
