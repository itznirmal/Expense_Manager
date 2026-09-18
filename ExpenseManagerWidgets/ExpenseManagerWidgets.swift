//
//  ExpenseManagerWidgets.swift
//  ExpenseManagerWidgets
//
//  Home-screen glance widgets: monthly spend + daily allowance.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), snapshot: WidgetFinanceSnapshot(
            monthExpense: 12500,
            monthIncome: 85000,
            remainingBudget: 18000,
            dailyAllowance: 1450,
            currencyCode: "INR",
            pendingReviewCount: 2
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let entry = SimpleEntry(date: Date(), snapshot: WidgetSnapshotStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetFinanceSnapshot
}

struct ExpenseManagerWidgetsEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            mediumView
        }
    }
    
    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This Month")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(format(entry.snapshot.monthExpense))
                .font(.title3.weight(.bold))
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Text("Left/day \(format(entry.snapshot.dailyAllowance))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private var mediumView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(format(entry.snapshot.monthExpense))
                    .font(.title2.weight(.bold))
                Text("Income \(format(entry.snapshot.monthIncome))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Daily budget")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(format(entry.snapshot.dailyAllowance))
                    .font(.title2.weight(.bold))
                if entry.snapshot.pendingReviewCount > 0 {
                    Text("\(entry.snapshot.pendingReviewCount) to review")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Text("Budget left \(format(entry.snapshot.remainingBudget))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    private func format(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = entry.snapshot.currencyCode
        formatter.maximumFractionDigits = 0
        return formatter.string(from: number) ?? "\(amount)"
    }
}

@main
struct ExpenseManagerWidgets: WidgetBundle {
    var body: some Widget {
        ExpenseGlanceWidget()
    }
}

struct ExpenseGlanceWidget: Widget {
    let kind: String = "ExpenseGlanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ExpenseManagerWidgetsEntryView(entry: entry)
        }
        .configurationDisplayName("Expense Glance")
        .description("See this month's spend and safe daily allowance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
