import SwiftData

// MARK: - Schema versions
// When you modify CorrectionRecord or CorrectionError (add/remove/rename a property):
//   1. Add a new SchemaVX enum with a bumped version number
//   2. Append it to GrammifyMigrationPlan.schemas
//   3. Add a MigrationStage from the previous version to the new one
//
// Example for a purely additive change (new optional/default property):
//
//   enum SchemaV2: VersionedSchema {
//       static var versionIdentifier = Schema.Version(2, 0, 0)
//       static var models: [any PersistentModel.Type] { [CorrectionRecord.self, CorrectionError.self] }
//   }
//
//   // In GrammifyMigrationPlan:
//   static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
//   static var stages: [MigrationStage] { [migrateV1toV2] }
//   static let migrateV1toV2 = MigrationStage.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
//
// For complex changes (renaming a property, transforming data), use MigrationStage.custom instead.

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [CorrectionRecord.self, CorrectionError.self]
    }
}

enum GrammifyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
