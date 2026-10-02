import SwiftUI

/// A short introduction; neither accounts nor budgets are required to begin.
public struct SpendingWelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var currency = CurrencyFormatter.defaultCurrencyCode

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "creditcard.and.123")
                        .font(.largeTitle)
                        .foregroundStyle(ColorTokens.brandPrimary)
                        .accessibilityHidden(true)
                    Text("A little clarity, every day.")
                        .font(.largeTitle.bold())
                    Text("Record spending in seconds. See where it goes. Add a budget whenever you want.")
                        .font(.title3)
                    Picker("Currency for new entries", selection: $currency) {
                        ForEach(CurrencyFormatter.supportedCurrencyCodes, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    .accessibilityIdentifier("onboardingCurrency")
                    Label("Your records stay on this device. No signup needed.", systemImage: "lock.shield")
                    Text("Back up from Settings to keep a recoverable copy. You can change the currency for new entries without changing old amounts.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Add my first expense") {
                        appState.preferredCurrencyCode = currency
                        appState.hasCompletedOnboarding = true
                        appState.presentSheet(.manualEntry(candidate: nil))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("beginTracking")
                    Button("Explore first") {
                        appState.preferredCurrencyCode = currency
                        appState.hasCompletedOnboarding = true
                    }
                    .frame(minHeight: 44)
                }
                .padding(24)
            }
            .navigationTitle("Expense Manager")
        }
    }
}

#Preview {
    SpendingWelcomeView().environment(AppState())
}
