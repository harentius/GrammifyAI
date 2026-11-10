import Foundation
import SwiftData

// Represents a single correction record in history
@Model
final class CorrectionRecord {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var originalText: String
    var correctedText: String
    @Relationship(deleteRule: .cascade) var errors: [CorrectionError]
    var language: String

    // Add index for efficient querying by timestamp and language
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        originalText: String,
        correctedText: String,
        errors: [CorrectionError] = [],
        language: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.originalText = originalText
        self.correctedText = correctedText
        self.errors = errors
        // Normalize language to lowercase canonical form for consistent querying
        self.language = ErrorCategory.normalizeLanguage(language)
    }
}

// Manages persistence of correction history using SwiftData
@MainActor
class HistoryStore: ObservableObject {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    // Save a new correction record
    func saveRecord(_ record: CorrectionRecord) {
        modelContext.insert(record)

        do {
            try modelContext.save()
        } catch {
            NSLog("Failed to save correction history: \(error.localizedDescription)")
        }
    }

    // Create and save a new correction record
    func createRecord(
        originalText: String,
        correctedText: String,
        errors: [CorrectionError],
        language: String
    ) {
        let record = CorrectionRecord(
            originalText: originalText,
            correctedText: correctedText,
            errors: errors,
            language: language
        )
        saveRecord(record)
    }

    // Fetch records for a specific time period
    func fetchRecords(from startDate: Date, to endDate: Date, language: String? = nil) -> [CorrectionRecord] {
        let actualStart = min(startDate, endDate)
        let actualEnd = max(startDate, endDate)
        let predicate: Predicate<CorrectionRecord>

        let trimmedLang = language?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedLang.isEmpty && trimmedLang.lowercased() != "all" {
            let normalizedLanguage = ErrorCategory.normalizeLanguage(trimmedLang)
            predicate = #Predicate<CorrectionRecord> { record in
                record.timestamp >= actualStart &&
                record.timestamp <= actualEnd &&
                record.language == normalizedLanguage
            }
        } else {
            predicate = #Predicate<CorrectionRecord> { record in
                record.timestamp >= actualStart &&
                record.timestamp <= actualEnd
            }
        }

        let descriptor = FetchDescriptor<CorrectionRecord>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            NSLog("Failed to fetch correction history: \(error.localizedDescription)")
            return []
        }
    }

    // Get total record count
    func getRecordCount(language: String? = nil) -> Int {
        let predicate: Predicate<CorrectionRecord>?

        let trimmedLang = language?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedLang.isEmpty && trimmedLang.lowercased() != "all" {
            let normalizedLanguage = ErrorCategory.normalizeLanguage(trimmedLang)
            predicate = #Predicate<CorrectionRecord> { record in
                record.language == normalizedLanguage
            }
        } else {
            predicate = nil
        }

        let descriptor = FetchDescriptor<CorrectionRecord>(predicate: predicate)

        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            NSLog("Failed to count records: \(error.localizedDescription)")
            return 0
        }
    }

    // Clear all history
    func clearHistory() {
        do {
            try modelContext.delete(model: CorrectionError.self)
            try modelContext.delete(model: CorrectionRecord.self)
            try modelContext.save()
        } catch {
            NSLog("Failed to clear history: \(error.localizedDescription)")
        }
    }

    // Get all unique languages in the database
    func getUniqueLanguages() -> [String] {
        var descriptor = FetchDescriptor<CorrectionRecord>(
            sortBy: [SortDescriptor(\.language)]
        )
        descriptor.propertiesToFetch = [\.language]

        do {
            let records = try modelContext.fetch(descriptor)
            let languages = Set(records.map { $0.language })
            return Array(languages).sorted()
        } catch {
            NSLog("Failed to fetch unique languages: \(error.localizedDescription)")
            return []
        }
    }

    // Get date range of all records (for determining available years)
    func getDateRange() -> (oldest: Date?, newest: Date?) {
        var oldestDescriptor = FetchDescriptor<CorrectionRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        oldestDescriptor.fetchLimit = 1
        oldestDescriptor.propertiesToFetch = [\.timestamp]

        var newestDescriptor = FetchDescriptor<CorrectionRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        newestDescriptor.fetchLimit = 1
        newestDescriptor.propertiesToFetch = [\.timestamp]

        do {
            let oldest = try modelContext.fetch(oldestDescriptor).first?.timestamp
            let newest = try modelContext.fetch(newestDescriptor).first?.timestamp
            return (oldest, newest)
        } catch {
            return (nil, nil)
        }
    }
}
