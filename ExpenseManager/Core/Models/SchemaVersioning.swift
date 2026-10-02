import SwiftData

/// Public alias for the current schema. The V1 snapshot and migration plan are
/// defined in `LegacySchemaV1.swift` so this file remains the single obvious
/// entry point for container code.
public typealias ExpenseManagerCurrentSchema = ExpenseManagerSchemaV2
