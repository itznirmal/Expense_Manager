//
//  CategoryComposerView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Modal Sheet for Creating Custom User Categories.
//

import SwiftUI

public struct CategoryComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appState) private var appState
    @Environment(\.dependencyContainer) private var container
    
    @State private var name: String = ""
    @State private var type: CategoryType = .expense
    @State private var selectedIcon: String = "tag.fill"
    @State private var selectedColorToken: String = "orange"
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    
    private let availableIcons: [String] = [
        "fork.knife", "cart.fill", "car.fill", "bag.fill", "bolt.fill", "film.fill",
        "cross.fill", "airplane", "gift.fill", "graduationcap.fill", "dumbbell.fill",
        "tshirt.fill", "pawprint.fill", "cup.and.saucer.fill", "banknote.fill",
        "chart.line.uptrend.xyaxis", "laptopcomputer", "wrench.and.screwdriver.fill",
        "gamecontroller.fill", "book.fill", "house.fill", "tag.fill"
    ]
    
    private let availableColorTokens: [String] = [
        "orange", "red", "yellow", "green", "teal", "blue", "indigo", "purple", "pink", "gray"
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Category Name & Type") {
                    TextField("Category Name (e.g. Pet Care)", text: $name)
                    
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(CategoryType.expense)
                        Text("Income").tag(CategoryType.income)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Icon & Color") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose Icon")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button(action: {
                                    selectedIcon = icon
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .frame(width: 44, height: 44)
                                        .foregroundStyle(selectedIcon == icon ? Color.white : ColorTokens.textPrimary)
                                        .background(selectedIcon == icon ? ColorTokens.color(for: selectedColorToken) : ColorTokens.backgroundTertiary)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Text("Choose Color")
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                            .padding(.top, 8)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(availableColorTokens, id: \.self) { token in
                                    Button(action: {
                                        selectedColorToken = token
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }) {
                                        Circle()
                                            .fill(ColorTokens.color(for: token))
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: selectedColorToken == token ? 3 : 0)
                                            )
                                            .shadow(color: selectedColorToken == token ? Color.black.opacity(0.2) : .clear, radius: 4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.criticalAccent)
                    }
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveCategory()
                        }
                    }
                    .font(Typography.headline)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }
    
    private func saveCategory() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a category name."
            return
        }
        
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        do {
            try await container.categoryService.createCategory(
                name: trimmed,
                parentCategoryID: nil,
                icon: selectedIcon,
                colorToken: selectedColorToken,
                type: type
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            appState.showToast(title: "Category Created", message: trimmed, type: .success)
            dismiss()
        } catch {
            errorMessage = "Failed to create category: \(error.localizedDescription)"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

#Preview {
    CategoryComposerView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
