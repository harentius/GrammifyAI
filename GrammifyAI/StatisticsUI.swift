import SwiftUI
import SwiftData
import Charts

struct StatisticsUI: View {
    @ObservedObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var historyStore: HistoryStore?

    // Selector states
    @State private var selectedLanguage: String = "all"
    @State private var availableLanguages: [String] = []
    @State private var selectedTimePeriod: TimePeriod = .weekly
    @State private var selectedErrorType: String = "ALL"

    // Date range states
    @State private var dailyStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    @State private var dailyEndDate: Date = Date()
    @State private var weeksCount: Int = 4
    @State private var monthsCount: Int = 3

    // Chart data
    @State private var currentRecords: [CorrectionRecord] = []
    @State private var trendData: [ChartDataPoint] = []
    @State private var comparisonData: [ErrorComparisonData] = []
    @State private var totalEntries: Int = 0
    @State private var matchingEntries: Int = 0
    @State private var errorFreeEntries: Int = 0
    @State private var showClearHistoryConfirmation: Bool = false

    private var availableErrorCategories: [ErrorCategory] {
        if selectedLanguage == "all" {
            return ErrorCategory.allCases
        } else {
            return ErrorCategory.categoriesForLanguage(selectedLanguage)
        }
    }

    private var chartCalendarUnit: Calendar.Component {
        switch selectedTimePeriod {
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .yearly: return .year
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Statistics")
                    .font(.title)
                Spacer()
            }
            .padding(.horizontal)

            // Selectors Row
            HStack(spacing: 16) {
                // Language Selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("Language").font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $selectedLanguage) {
                        Text("All Languages").tag("all")
                        ForEach(availableLanguages, id: \.self) { lang in
                            Text(lang.capitalized).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedLanguage) { _, _ in
                        let allowed = availableErrorCategories.map { $0.rawValue }
                        if selectedErrorType != "ALL" && !allowed.contains(selectedErrorType) {
                            selectedErrorType = "ALL"
                        }
                        refreshData()
                    }
                }

                // Time Period Selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Period").font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $selectedTimePeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTimePeriod) { _, _ in refreshData() }
                }

                // Error Type Selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("Error Type").font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $selectedErrorType) {
                        Text("All Types").tag("ALL")
                        ForEach(availableErrorCategories, id: \.rawValue) { category in
                            Text("\(category.rawValue) - \(category.description)").tag(category.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedErrorType) { _, _ in refreshData() }
                }
            }
            .padding(.horizontal)

            // Custom Range Controls (conditional)
            if selectedTimePeriod == .daily {
                HStack {
                    DatePicker("From:", selection: $dailyStartDate, displayedComponents: .date)
                    DatePicker("To:", selection: $dailyEndDate, displayedComponents: .date)
                }
                .padding(.horizontal)
                .onChange(of: dailyStartDate) { _, _ in refreshData() }
                .onChange(of: dailyEndDate) { _, _ in refreshData() }
            } else if selectedTimePeriod == .weekly {
                HStack(spacing: 8) {
                    Text("Last")
                    TextField("", value: $weeksCount, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                    Stepper("", value: $weeksCount, in: 1...52)
                        .labelsHidden()
                    Text("weeks")
                }
                .padding(.horizontal)
                .onChange(of: weeksCount) { _, newValue in
                    let clamped = min(max(newValue, 1), 52)
                    if clamped != newValue {
                        weeksCount = clamped
                    } else {
                        refreshData()
                    }
                }
            } else if selectedTimePeriod == .monthly {
                HStack(spacing: 8) {
                    Text("Last")
                    TextField("", value: $monthsCount, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                    Stepper("", value: $monthsCount, in: 1...24)
                        .labelsHidden()
                    Text("months")
                }
                .padding(.horizontal)
                .onChange(of: monthsCount) { _, newValue in
                    let clamped = min(max(newValue, 1), 24)
                    if clamped != newValue {
                        monthsCount = clamped
                    } else {
                        refreshData()
                    }
                }
            }

            Divider()

            // Total entries info
            HStack {
                if selectedErrorType == "ALL" {
                    if totalEntries > 0 {
                        let errorFreePct = Double(errorFreeEntries) / Double(totalEntries) * 100.0
                        let withErrorsCount = totalEntries - errorFreeEntries
                        let withErrorsPct = Double(withErrorsCount) / Double(totalEntries) * 100.0
                        Text("Total checks in selected period: \(totalEntries) · Error-free: \(errorFreeEntries) (\(errorFreePct, specifier: "%.1f")%) · With errors: \(withErrorsCount) (\(withErrorsPct, specifier: "%.1f")%)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Total checks in selected period: 0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    let matchingPct = totalEntries > 0 ? (Double(matchingEntries) / Double(totalEntries) * 100.0) : 0.0
                    Text("Total checks in selected period: \(totalEntries) (\(matchingEntries) with \(selectedErrorType) — \(matchingPct, specifier: "%.1f")%)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)

            // Charts Section (scrollable)
            ScrollView {
                VStack(spacing: 24) {
                    // Line Chart: Trend over time
                    VStack(alignment: .leading) {
                        Text("Error Rate Over Time (%)")
                            .font(.headline)
                            .padding(.horizontal)

                        if trendData.isEmpty {
                            Text("No data available for the selected period.")
                                .foregroundColor(.secondary)
                                .frame(height: 250)
                                .frame(maxWidth: .infinity)
                        } else {
                            Chart(trendData) { dataPoint in
                                if selectedErrorType == "ALL" {
                                    if dataPoint.errorRates.isEmpty {
                                        LineMark(
                                            x: .value("Date", dataPoint.date, unit: chartCalendarUnit),
                                            y: .value("Rate (%)", dataPoint.totalRate)
                                        )
                                        .foregroundStyle(.green)

                                        PointMark(
                                            x: .value("Date", dataPoint.date, unit: chartCalendarUnit),
                                            y: .value("Rate (%)", dataPoint.totalRate)
                                        )
                                        .foregroundStyle(.green)
                                    } else {
                                        ForEach(dataPoint.errorRates.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { category in
                                            let rate = dataPoint.errorRates[category] ?? 0
                                            let seriesLabel = "\(category.rawValue) - \(category.description)"
                                            LineMark(
                                                x: .value("Date", dataPoint.date, unit: chartCalendarUnit),
                                                y: .value("Rate (%)", rate)
                                            )
                                            .foregroundStyle(by: .value("Error Type", seriesLabel))
                                            .symbol(by: .value("Error Type", seriesLabel))

                                            PointMark(
                                                x: .value("Date", dataPoint.date, unit: chartCalendarUnit),
                                                y: .value("Rate (%)", rate)
                                            )
                                            .foregroundStyle(by: .value("Error Type", seriesLabel))
                                        }
                                    }
                                } else if let category = ErrorCategory(rawValue: selectedErrorType) {
                                    let rate = dataPoint.errorRates[category] ?? 0
                                    LineMark(
                                        x: .value("Date", dataPoint.date, unit: chartCalendarUnit),
                                        y: .value("Rate (%)", rate)
                                    )
                                    .foregroundStyle(.blue)

                                    PointMark(
                                        x: .value("Date", dataPoint.date, unit: chartCalendarUnit),
                                        y: .value("Rate (%)", rate)
                                    )
                                    .foregroundStyle(.blue)
                                }
                            }
                            .chartYScale(domain: 0...100)
                            .chartXAxis {
                                AxisMarks { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    switch selectedTimePeriod {
                                    case .daily, .weekly:
                                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                    case .monthly:
                                        AxisValueLabel(format: .dateTime.year().month(.abbreviated))
                                    case .yearly:
                                        AxisValueLabel(format: .dateTime.year())
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading, values: [0, 20, 40, 60, 80, 100]) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let v = value.as(Double.self) {
                                            Text("\(v, specifier: "%.0f")%")
                                        }
                                    }
                                }
                            }
                            .frame(height: 250)
                            .padding()
                        }
                    }

                    Divider()

                    // Bar Chart: Error distribution
                    VStack(alignment: .leading) {
                        Text("Error Distribution (% of entries)")
                            .font(.headline)
                            .padding(.horizontal)

                        if comparisonData.isEmpty {
                            Text("No error records found for the selected period.")
                                .foregroundColor(.secondary)
                                .frame(height: 250)
                                .frame(maxWidth: .infinity)
                        } else {
                            Chart(comparisonData) { item in
                                BarMark(
                                    x: .value("Category", item.category.rawValue),
                                    y: .value("Rate (%)", item.percentage)
                                )
                                .foregroundStyle(by: .value("Category", "\(item.category.rawValue) - \(item.category.description)"))
                                .annotation(position: .top) {
                                    Text("\(item.percentage, specifier: "%.1f")%")
                                        .font(.caption2)
                                }
                            }
                            .chartYScale(domain: 0...110)
                            .chartYAxis {
                                AxisMarks(position: .leading, values: [0, 20, 40, 60, 80, 100]) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let v = value.as(Double.self) {
                                            Text("\(v, specifier: "%.0f")%")
                                        }
                                    }
                                }
                            }
                            .frame(height: 250)
                            .padding()
                        }
                    }
                }
            }

            Divider()

            // Footer: Export & Clear History buttons
            HStack {
                Button("Export CSV") {
                    exportToCSV()
                }
                .disabled(currentRecords.isEmpty)

                Spacer()

                Button("Clear History…", role: .destructive) {
                    showClearHistoryConfirmation = true
                }
                .disabled(availableLanguages.isEmpty && currentRecords.isEmpty)
            }
            .padding(.horizontal)
            .alert("Clear Correction History?", isPresented: $showClearHistoryConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All History", role: .destructive) {
                    historyStore?.clearHistory()
                    selectedLanguage = "all"
                    appState.historyVersion += 1
                    loadAvailableLanguages()
                    refreshData()
                }
            } message: {
                Text("This will permanently delete all recorded grammar checks and statistics. This action cannot be undone.")
            }
        }
        .padding()
        .frame(minWidth: 800, minHeight: 700)
        .onAppear {
            appState.showStatisticsUI = true
            initializeStore()
            loadAvailableLanguages()
            refreshData()
        }
        .onChange(of: appState.historyVersion) { _, _ in
            loadAvailableLanguages()
            if selectedLanguage != "all" && !availableLanguages.contains(selectedLanguage) {
                selectedLanguage = "all"
            }
            refreshData()
        }
        .onDisappear {
            appState.showStatisticsUI = false
        }
    }

    // Helper methods

    @MainActor
    private func initializeStore() {
        if historyStore == nil {
            historyStore = HistoryStore(modelContainer: modelContext.container)
        }
    }

    @MainActor
    private func loadAvailableLanguages() {
        guard let store = historyStore else { return }
        availableLanguages = store.getUniqueLanguages()
    }

    @MainActor
    private func refreshData() {
        guard let store = historyStore else { return }

        let (startDate, endDate) = calculateDateRange()
        let processor = StatisticsDataProcessor(historyStore: store)

        // Single database fetch
        let records = processor.fetchRecords(
            language: selectedLanguage == "all" ? nil : selectedLanguage,
            startDate: startDate,
            endDate: endDate
        )
        currentRecords = records

        // Process trend data
        trendData = processor.processTrendData(
            records: records,
            period: selectedTimePeriod,
            language: selectedLanguage == "all" ? nil : selectedLanguage,
            errorType: selectedErrorType == "ALL" ? nil : selectedErrorType
        )

        // Process comparison data
        comparisonData = processor.processComparisonData(
            records: records,
            errorType: selectedErrorType == "ALL" ? nil : selectedErrorType
        )

        // Record counts
        totalEntries = records.count
        errorFreeEntries = records.filter { $0.errors.isEmpty }.count
        if selectedErrorType == "ALL" {
            matchingEntries = totalEntries
        } else {
            matchingEntries = records.filter { record in
                record.errors.contains { $0.category.rawValue == selectedErrorType }
            }.count
        }
    }

    private func calculateDateRange() -> (Date, Date) {
        let now = Date()
        let calendar = Calendar.current

        switch selectedTimePeriod {
        case .daily:
            let start = min(dailyStartDate, dailyEndDate).startOfDay()
            let end = max(dailyStartDate, dailyEndDate).endOfDay()
            return (start, end)
        case .weekly:
            let validWeeks = min(max(1, weeksCount), 52)
            let currentWeekStart = now.startOfWeek()
            let start = calendar.date(byAdding: .weekOfYear, value: -(validWeeks - 1), to: currentWeekStart) ?? currentWeekStart
            return (start, now)
        case .monthly:
            let validMonths = min(max(1, monthsCount), 24)
            let currentMonthStart = now.startOfMonth()
            let start = calendar.date(byAdding: .month, value: -(validMonths - 1), to: currentMonthStart) ?? currentMonthStart
            return (start, now)
        case .yearly:
            // Get all available data
            if let store = historyStore {
                let (oldest, newest) = store.getDateRange()
                let start = (oldest ?? now).startOfYear()
                let end = (newest ?? now).endOfDay()
                return (start, end)
            }
            return (now.startOfYear(), now)
        }
    }

    private func escapeCSVField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private func exportToCSV() {
        let records = currentRecords

        // Filter by error type if needed
        let filteredRecords: [CorrectionRecord]
        if selectedErrorType != "ALL" {
            filteredRecords = records.filter { record in
                record.errors.contains { $0.category.rawValue == selectedErrorType }
            }
        } else {
            filteredRecords = records
        }

        // Build CSV
        var csv = "Timestamp,Language,Error Category,Original Fragment,Corrected Fragment,Original Text,Corrected Text\n"
        let dateFormatter = ISO8601DateFormatter()

        for record in filteredRecords {
            let timestamp = escapeCSVField(dateFormatter.string(from: record.timestamp))
            let language = escapeCSVField(record.language)
            let originalText = escapeCSVField(record.originalText)
            let correctedText = escapeCSVField(record.correctedText)

            if record.errors.isEmpty {
                if selectedErrorType == "ALL" {
                    csv += "\(timestamp),\(language),\"NONE\",\"\",\"\",\(originalText),\(correctedText)\n"
                }
            } else {
                for error in record.errors {
                    if selectedErrorType != "ALL" && error.category.rawValue != selectedErrorType {
                        continue
                    }

                    let category = escapeCSVField(error.category.rawValue)
                    let originalFrag = escapeCSVField(error.originalFragment ?? "")
                    let correctedFrag = escapeCSVField(error.correctedFragment ?? "")

                    csv += "\(timestamp),\(language),\(category),\(originalFrag),\(correctedFrag),\(originalText),\(correctedText)\n"
                }
            }
        }

        // Save dialog
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "grammify_statistics_\(selectedTimePeriod.rawValue.lowercased()).csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                    NSLog("Statistics exported to \(url.path)")
                } catch {
                    NSLog("Failed to export statistics: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    StatisticsUI(appState: AppState())
        .frame(width: 800, height: 700)
}
