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
    let overallErrorRate: Double

    init(date: Date, errorRates: [ErrorCategory: Double], recordCount: Int, overallErrorRate: Double = 0.0) {
        self.date = date
        self.errorRates = errorRates
        self.recordCount = recordCount
        self.overallErrorRate = overallErrorRate
    }

    var totalRate: Double {
        overallErrorRate
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

    func endOfDay() -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfDay()) ?? self
    }

    func startOfWeek() -> Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: self)?.start ?? self
    }

    func startOfMonth() -> Date {
        Calendar.current.dateInterval(of: .month, for: self)?.start ?? self
    }

    func startOfYear() -> Date {
        Calendar.current.dateInterval(of: .year, for: self)?.start ?? self
    }
}
