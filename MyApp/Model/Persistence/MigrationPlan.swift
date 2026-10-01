import SwiftData

/// Schema history. Add each new `SchemaVn` to `schemas` and a stage to `stages`.
enum MySkinMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
