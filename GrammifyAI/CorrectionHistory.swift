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
        // Normalize language to lowercase for consistent querying
        self.language = language.lowercased()
    }
}

// Manages persistence of correction history using SwiftData
@MainActor
class HistoryStore: ObservableObject {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
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
        let predicate: Predicate<CorrectionRecord>

        if let language = language {
            // Language is stored in lowercase, so normalize the search term
            let normalizedLanguage = language.lowercased()
            predicate = #Predicate<CorrectionRecord> { record in
                record.timestamp >= startDate &&
                record.timestamp <= endDate &&
                record.language == normalizedLanguage
            }
        } else {
            predicate = #Predicate<CorrectionRecord> { record in
                record.timestamp >= startDate &&
                record.timestamp <= endDate
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

    // Get statistics for a specific time period
    func getStatistics(from startDate: Date, to endDate: Date, language: String? = nil) -> [ErrorCategory: Int] {
        let records = fetchRecords(from: startDate, to: endDate, language: language)

        var stats: [ErrorCategory: Int] = [:]
        for record in records {
            for error in record.errors {
                stats[error.category, default: 0] += 1
            }
        }

        return stats
    }

    // Get weekly statistics
    func getWeeklyStatistics(language: String? = nil) -> [ErrorCategory: Int] {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        return getStatistics(from: weekAgo, to: now, language: language)
    }

    // Get monthly statistics
    func getMonthlyStatistics(language: String? = nil) -> [ErrorCategory: Int] {
        let now = Date()
        let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        return getStatistics(from: monthAgo, to: now, language: language)
    }

    // Get total record count
    func getRecordCount(language: String? = nil) -> Int {
        let predicate: Predicate<CorrectionRecord>?

        if let language = language {
            // Language is stored in lowercase, so normalize the search term
            let normalizedLanguage = language.lowercased()
            predicate = #Predicate<CorrectionRecord> { record in
                record.language == normalizedLanguage
            }
        } else {
            predicate = nil
        }

        let descriptor = FetchDescriptor<CorrectionRecord>(predicate: predicate)

        do {
            let records = try modelContext.fetch(descriptor)
            return records.count
        } catch {
            NSLog("Failed to count records: \(error.localizedDescription)")
            return 0
        }
    }

    // Export all history as array (for CSV export)
    func exportHistory() -> [CorrectionRecord] {
        let descriptor = FetchDescriptor<CorrectionRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            NSLog("Failed to export history: \(error.localizedDescription)")
            return []
        }
    }

    // Delete records older than a specific date
    func deleteRecordsOlderThan(date: Date) {
        let predicate = #Predicate<CorrectionRecord> { record in
            record.timestamp < date
        }

        let descriptor = FetchDescriptor<CorrectionRecord>(predicate: predicate)

        do {
            let oldRecords = try modelContext.fetch(descriptor)
            for record in oldRecords {
                modelContext.delete(record)
            }
            try modelContext.save()
            NSLog("Deleted \(oldRecords.count) old records")
        } catch {
            NSLog("Failed to delete old records: \(error.localizedDescription)")
        }
    }

    // Clear all history
    func clearHistory() {
        do {
            try modelContext.delete(model: CorrectionRecord.self)
            try modelContext.save()
        } catch {
            NSLog("Failed to clear history: \(error.localizedDescription)")
        }
    }

    // Get all unique languages in the database
    func getUniqueLanguages() -> [String] {
        let descriptor = FetchDescriptor<CorrectionRecord>(
            sortBy: [SortDescriptor(\.language)]
        )

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
        let descriptor = FetchDescriptor<CorrectionRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )

        do {
            let records = try modelContext.fetch(descriptor)
            return (records.first?.timestamp, records.last?.timestamp)
        } catch {
            return (nil, nil)
        }
    }
}
