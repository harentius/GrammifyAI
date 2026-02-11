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

    // Process records into trend data points grouped by time period
    func processTrendData(
        period: TimePeriod,
        language: String?,
        errorType: String?,
        startDate: Date,
        endDate: Date
    ) -> [ChartDataPoint] {
        // Fetch records for date range with language filter
        let records = historyStore.fetchRecords(
            from: startDate,
            to: endDate,
            language: language == "all" ? nil : language
        )

        // Group records by date bucket and track which categories each record has
        var bucketRecordCounts: [Date: Int] = [:]
        var bucketCategoryRecordCounts: [Date: [ErrorCategory: Int]] = [:]

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

            // Count distinct categories present in this record (each category counted once per record)
            let categoriesInRecord = Set(record.errors.map { $0.category })
            for category in categoriesInRecord {
                if let filterType = errorType, filterType != "ALL" {
                    guard category.rawValue == filterType else { continue }
                }
                if bucketCategoryRecordCounts[bucketDate] == nil {
                    bucketCategoryRecordCounts[bucketDate] = [:]
                }
                bucketCategoryRecordCounts[bucketDate]![category, default: 0] += 1
            }
        }

        // Convert to ChartDataPoint array with percentages
        return bucketRecordCounts.map { date, totalRecords in
            let categoryRecordCounts = bucketCategoryRecordCounts[date] ?? [:]
            let rates: [ErrorCategory: Double] = categoryRecordCounts.mapValues { count in
                Double(count) / Double(totalRecords) * 100.0
            }
            return ChartDataPoint(date: date, errorRates: rates, recordCount: totalRecords)
        }.sorted { $0.date < $1.date }
    }

    // Process records into comparison data (percentage of records with each error category)
    func processComparisonData(
        language: String?,
        errorType: String?,
        startDate: Date,
        endDate: Date
    ) -> [ErrorComparisonData] {
        let records = historyStore.fetchRecords(
            from: startDate,
            to: endDate,
            language: language == "all" ? nil : language
        )

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

    // Get total record count for a date range
    func totalRecordCount(
        language: String?,
        startDate: Date,
        endDate: Date
    ) -> Int {
        let records = historyStore.fetchRecords(
            from: startDate,
            to: endDate,
            language: language == "all" ? nil : language
        )
        return records.count
    }
}
