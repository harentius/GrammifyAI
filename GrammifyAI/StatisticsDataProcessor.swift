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

        // Group by date bucket (day/week/month/year)
        var buckets: [Date: [ErrorCategory: Int]] = [:]

        for record in records {
            // Determine bucket date based on period
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

            // Count errors by category
            for error in record.errors {
                // Apply error type filter if specified
                if let filterType = errorType, filterType != "ALL" {
                    guard error.category.rawValue == filterType else { continue }
                }

                if buckets[bucketDate] == nil {
                    buckets[bucketDate] = [:]
                }
                buckets[bucketDate]![error.category, default: 0] += 1
            }
        }

        // Convert to ChartDataPoint array, sorted chronologically
        return buckets.map { date, counts in
            ChartDataPoint(date: date, errorCounts: counts)
        }.sorted { $0.date < $1.date }
    }

    // Process records into comparison data (total counts by category)
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

        // Count errors by category
        var categoryCounts: [ErrorCategory: Int] = [:]

        for record in records {
            for error in record.errors {
                // Apply error type filter if specified
                if let filterType = errorType, filterType != "ALL" {
                    guard error.category.rawValue == filterType else { continue }
                }
                categoryCounts[error.category, default: 0] += 1
            }
        }

        // Convert to ErrorComparisonData array, sorted by count descending
        return categoryCounts.map { category, count in
            ErrorComparisonData(category: category, count: count)
        }.sorted { $0.count > $1.count }
    }
}
