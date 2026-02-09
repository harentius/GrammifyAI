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
    @State private var trendData: [ChartDataPoint] = []
    @State private var comparisonData: [ErrorComparisonData] = []

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
                    .onChange(of: selectedLanguage) { _, _ in refreshData() }
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
                        ForEach(ErrorCategory.allCases, id: \.rawValue) { category in
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
                HStack {
                    Text("Last")
                    TextField("", value: $weeksCount, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                    Text("weeks")
                }
                .padding(.horizontal)
                .onChange(of: weeksCount) { _, _ in refreshData() }
            } else if selectedTimePeriod == .monthly {
                HStack {
                    Text("Last")
                    TextField("", value: $monthsCount, format: .number)
                        .frame(width: 50)
                        .textFieldStyle(.roundedBorder)
                    Text("months")
                }
                .padding(.horizontal)
                .onChange(of: monthsCount) { _, _ in refreshData() }
            }

            Divider()

            // Charts Section (scrollable)
            ScrollView {
                VStack(spacing: 24) {
                    // Line Chart: Trend over time
                    VStack(alignment: .leading) {
                        Text("Error Trend Over Time")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(trendData) { dataPoint in
                            if selectedErrorType == "ALL" {
                                // Show stacked lines for all error types
                                ForEach(dataPoint.errorCounts.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { category in
                                    LineMark(
                                        x: .value("Date", dataPoint.date),
                                        y: .value("Count", dataPoint.errorCounts[category] ?? 0)
                                    )
                                    .foregroundStyle(by: .value("Error Type", category.rawValue))
                                    .symbol(by: .value("Error Type", category.rawValue))
                                }
                            } else {
                                // Show single line for selected error type
                                LineMark(
                                    x: .value("Date", dataPoint.date),
                                    y: .value("Count", dataPoint.totalCount)
                                )
                                .foregroundStyle(.blue)
                            }
                        }
                        .frame(height: 250)
                        .padding()
                    }

                    Divider()

                    // Bar Chart: Error distribution
                    VStack(alignment: .leading) {
                        Text("Error Distribution")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(comparisonData) { item in
                            BarMark(
                                x: .value("Category", item.category.rawValue),
                                y: .value("Count", item.count)
                            )
                            .foregroundStyle(by: .value("Category", item.category.rawValue))
                        }
                        .frame(height: 250)
                        .padding()
                    }
                }
            }

            Divider()

            // Footer: Export button
            HStack {
                Button("Export CSV") {
                    exportToCSV()
                }
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(minWidth: 800, minHeight: 700)
        .onAppear {
            appState.showStatisticsUI = true
            initializeStore()
            loadAvailableLanguages()
            refreshData()
        }
        .onDisappear {
            appState.showStatisticsUI = false
        }
    }

    // Helper methods

    @MainActor
    private func initializeStore() {
        if historyStore == nil,
           let container = try? modelContext.container {
            historyStore = HistoryStore(modelContainer: container)
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

        // Process trend data
        trendData = processor.processTrendData(
            period: selectedTimePeriod,
            language: selectedLanguage == "all" ? nil : selectedLanguage,
            errorType: selectedErrorType == "ALL" ? nil : selectedErrorType,
            startDate: startDate,
            endDate: endDate
        )

        // Process comparison data
        comparisonData = processor.processComparisonData(
            language: selectedLanguage == "all" ? nil : selectedLanguage,
            errorType: selectedErrorType == "ALL" ? nil : selectedErrorType,
            startDate: startDate,
            endDate: endDate
        )
    }

    private func calculateDateRange() -> (Date, Date) {
        let now = Date()
        let calendar = Calendar.current

        switch selectedTimePeriod {
        case .daily:
            return (dailyStartDate, dailyEndDate)
        case .weekly:
            let start = calendar.date(byAdding: .weekOfYear, value: -weeksCount, to: now) ?? now
            return (start, now)
        case .monthly:
            let start = calendar.date(byAdding: .month, value: -monthsCount, to: now) ?? now
            return (start, now)
        case .yearly:
            // Get all available data
            if let store = historyStore {
                let (oldest, newest) = store.getDateRange()
                return (oldest ?? now, newest ?? now)
            }
            return (now, now)
        }
    }

    private func exportToCSV() {
        guard let store = historyStore else { return }

        let (startDate, endDate) = calculateDateRange()
        let records = store.fetchRecords(
            from: startDate,
            to: endDate,
            language: selectedLanguage == "all" ? nil : selectedLanguage
        )

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
        var csv = "Timestamp,Language,Error Category,Original Fragment,Corrected Fragment\n"
        let dateFormatter = ISO8601DateFormatter()

        for record in filteredRecords {
            for error in record.errors {
                if selectedErrorType != "ALL" && error.category.rawValue != selectedErrorType {
                    continue
                }

                let timestamp = dateFormatter.string(from: record.timestamp)
                let original = (error.originalFragment ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                let corrected = (error.correctedFragment ?? "").replacingOccurrences(of: "\"", with: "\"\"")

                csv += "\"\(timestamp)\",\"\(record.language)\",\"\(error.category.rawValue)\",\"\(original)\",\"\(corrected)\"\n"
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
