import SwiftData

/// Schema history. Add each new `SchemaVn` to `schemas` and a stage to `stages`.
enum MySkinMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2]
    }

    /// V2 only adds optional fields (or ones with a default), so no custom code is needed.
    static let v1ToV2 = MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
}
