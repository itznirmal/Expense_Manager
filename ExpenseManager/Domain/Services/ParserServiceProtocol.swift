//
//  ParserServiceProtocol.swift
//  ExpenseManager
//
//  Created for Expense Manager iOS.
//  Natural Language & Ingestion Parser Protocol.
//

import Foundation

/// Service protocol defining parsing operations across Smart Text, Voice transcripts, and SMS payloads.
public protocol ParserServiceProtocol: Sendable {
    
    /// Parses a raw input string from a specified source into a candidate transaction.
    func parse(text: String, source: InputSource) async throws -> TransactionCandidate
    
    /// Determines whether the parser can extract meaningful financial content from text.
    func canHandle(text: String) -> Bool
}
