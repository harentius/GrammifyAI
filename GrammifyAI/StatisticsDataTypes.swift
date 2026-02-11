import Foundation
import SwiftUI

// Time period selector options
enum TimePeriod: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
}

// Data point for trend line chart
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let errorRates: [ErrorCategory: Double]
    let recordCount: Int

    var totalRate: Double {
        guard recordCount > 0 else { return 0 }
        // Overall % of records that had at least one error (stored separately)
        return errorRates.values.max() ?? 0
    }
}

// Data point for comparison bar chart
struct ErrorComparisonData: Identifiable {
    let id = UUID()
    let category: ErrorCategory
    let percentage: Double
    let count: Int
}

// Date bucketing utilities for grouping records
extension Date {
    func startOfDay() -> Date {
        Calendar.current.startOfDay(for: self)
    }

    func startOfWeek() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    func startOfYear() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self)
        return calendar.date(from: components) ?? self
    }
}
