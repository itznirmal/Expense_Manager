//
//  SmartEntryComposerView.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Smart Text Natural Language Entry View (Legacy alias forwarding to SmartTextComposerView).
//

import SwiftUI

public struct SmartEntryComposerView: View {
    public init() {}
    
    public var body: some View {
        SmartTextComposerView()
    }
}

#Preview {
    SmartEntryComposerView()
        .environment(AppState())
        .environment(\.dependencyContainer, .mock())
}
