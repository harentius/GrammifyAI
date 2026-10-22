import Foundation
import SwiftData

@MainActor
class StatisticsDataProcessor {
    private let historyStore: HistoryStore

    init(historyStore: HistoryStore) {
        self.historyStore = historyStore
    }

    // Get available languages from stored records
    func getAvailableLanguages() -> [String] {
        historyStore.getUniqueLanguages()
    }

    // Fetch records once for a date range with language filter
    func fetchRecords(
        language: String?,
        startDate: Date,
        endDate: Date
    ) -> [CorrectionRecord] {
        let normalizedLang = (language == "all" || language?.isEmpty == true) ? nil : language
        return historyStore.fetchRecords(
            from: startDate,
            to: endDate,
            language: normalizedLang
        )
    }

    // Process records into trend data points grouped by time period
    func processTrendData(
        records: [CorrectionRecord],
        period: TimePeriod,
        language: String?,
        errorType: String?
    ) -> [ChartDataPoint] {
        // Group records by date bucket and track which categories each record has
        var bucketRecordCounts: [Date: Int] = [:]
        var bucketRecordsWithErrorCounts: [Date: Int] = [:]
        var bucketCategoryRecordCounts: [Date: [ErrorCategory: Int]] = [:]

        // Determine all categories present across records
        var presentCategories = Set<ErrorCategory>()
        for record in records {
            for error in record.errors {
                presentCategories.insert(error.category)
            }
        }

        // Filter categories if specific errorType is requested
        let filteredCategory: ErrorCategory? = {
            if let errorType = errorType, errorType != "ALL" {
                return ErrorCategory(rawValue: errorType)
            }
            return nil
        }()

        let trackedCategories: [ErrorCategory] = {
            if let specific = filteredCategory {
                return [specific]
            }
            return Array(presentCategories).sorted { $0.rawValue < $1.rawValue }
        }()

        for record in records {
            let bucketDate: Date
            switch period {
            case .daily:
                bucketDate = record.timestamp.startOfDay()
            case .weekly:
                bucketDate = record.timestamp.startOfWeek()
            case .monthly:
                bucketDate = record.timestamp.startOfMonth()
            case .yearly:
                bucketDate = record.timestamp.startOfYear()
            }

            bucketRecordCounts[bucketDate, default: 0] += 1
            if !record.errors.isEmpty {
                bucketRecordsWithErrorCounts[bucketDate, default: 0] += 1
            }

            // Count distinct categories present in this record (each category counted once per record)
            let categoriesInRecord = Set(record.errors.map { $0.category })
            for category in categoriesInRecord {
                if let specific = filteredCategory, category != specific {
                    continue
                }
                if bucketCategoryRecordCounts[bucketDate] == nil {
                    bucketCategoryRecordCounts[bucketDate] = [:]
                }
                bucketCategoryRecordCounts[bucketDate]![category, default: 0] += 1
            }
        }

        // Convert to ChartDataPoint array with percentages
        // Ensure every tracked category has an explicit value (0.0 if not present) for every bucket
        return bucketRecordCounts.map { date, totalRecords in
            let categoryRecordCounts = bucketCategoryRecordCounts[date] ?? [:]
            var rates: [ErrorCategory: Double] = [:]
            for cat in trackedCategories {
                let count = categoryRecordCounts[cat] ?? 0
                rates[cat] = Double(count) / Double(totalRecords) * 100.0
            }

            let recordsWithError = bucketRecordsWithErrorCounts[date] ?? 0
            let overallRate = totalRecords > 0 ? (Double(recordsWithError) / Double(totalRecords) * 100.0) : 0.0

            return ChartDataPoint(
                date: date,
                errorRates: rates,
                recordCount: totalRecords,
                overallErrorRate: overallRate
            )
        }.sorted { $0.date < $1.date }
    }

    // Convenience overload for backwards compatibility
    func processTrendData(
        period: TimePeriod,
        language: String?,
        errorType: String?,
        startDate: Date,
        endDate: Date
    ) -> [ChartDataPoint] {
        let records = fetchRecords(language: language, startDate: startDate, endDate: endDate)
        return processTrendData(records: records, period: period, language: language, errorType: errorType)
    }

    // Process records into comparison data (percentage of records with each error category)
    func processComparisonData(
        records: [CorrectionRecord],
        errorType: String?
    ) -> [ErrorComparisonData] {
        guard !records.isEmpty else { return [] }

        // Count how many records have each error category (each category counted once per record)
        var categoryRecordCounts: [ErrorCategory: Int] = [:]

        for record in records {
            let categoriesInRecord = Set(record.errors.map { $0.category })
            for category in categoriesInRecord {
                if let filterType = errorType, filterType != "ALL" {
                    guard category.rawValue == filterType else { continue }
                }
                categoryRecordCounts[category, default: 0] += 1
            }
        }

        let totalRecords = Double(records.count)

        // Convert to ErrorComparisonData array, sorted by percentage descending
        return categoryRecordCounts.map { category, count in
            ErrorComparisonData(
                category: category,
                percentage: Double(count) / totalRecords * 100.0,
                count: count
            )
        }.sorted { $0.percentage > $1.percentage }
    }

    // Convenience overload for backwards compatibility
    func processComparisonData(
        language: String?,
        errorType: String?,
        startDate: Date,
        endDate: Date
    ) -> [ErrorComparisonData] {
        let records = fetchRecords(language: language, startDate: startDate, endDate: endDate)
        return processComparisonData(records: records, errorType: errorType)
    }

    // Get total record count for a date range
    func totalRecordCount(
        language: String?,
        startDate: Date,
        endDate: Date
    ) -> Int {
        let records = fetchRecords(language: language, startDate: startDate, endDate: endDate)
        return records.count
    }
}
