import SwiftData

/// Schema history. Add each new `SchemaVn` to `schemas` and a stage to `stages`.
enum MySkinMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [v1ToV2, v2ToV3]
    }

    /// V2 only adds optional fields (or ones with a default), so no custom code is needed.
    static let v1ToV2 = MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)

    /// V3 only adds food to the check-in (optional / defaulted), so no custom code is needed.
    static let v2ToV3 = MigrationStage.lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)
}
