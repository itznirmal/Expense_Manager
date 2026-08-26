import SwiftData

/// Schema Version 1 Definition
public enum ExpenseManagerSchemaV1: VersionedSchema {
    public static var versionIdentifier = Schema.Version(1, 0, 0)
    
    public static var models: [any PersistentModel.Type] {
        [
            TransactionRecord.self,
            AccountRecord.self,
            CategoryRecord.self,
            BudgetRecord.self,
            TagRecord.self,
            MerchantRuleRecord.self,
            ImportFingerprintRecord.self
        ]
    }
}

/// Defines the migration plan across schema versions for the SwiftData model container.
public enum ExpenseManagerMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [ExpenseManagerSchemaV1.self]
    }
    
    public static var stages: [MigrationStage] {
        // No migrations yet since V1 is the baseline.
        []
    }
}
