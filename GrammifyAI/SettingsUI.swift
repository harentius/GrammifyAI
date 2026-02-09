import SwiftUI
import KeyboardShortcuts
import SwiftData

struct SettingsUI: View {
    @StateObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @State private var historyStore: HistoryStore?
    @State private var apiUrl: String = SettingsManager.getAIUrl()
    @State private var model: String = SettingsManager.getAIModel()
    @State private var openAIKey: String = SettingsManager.getAIApiToken()
    @State private var launchAtLogin: Bool = SettingsManager.getLaunchAtLogin()
    @State private var historyCount: Int = 0
    @State private var showingClearConfirmation: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            if appState.showSettingsUI {
                HStack {
                    Text("API key")
                    SecureField("API key", text: $openAIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                }

                HStack {
                    Text("API URL")
                    TextField("API URL", text: $apiUrl)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                }

                HStack {
                    Text("Model name")
                    TextField("Model name", text: $model)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                }

                Form {
                    KeyboardShortcuts.Recorder("Improve writing shortcut:", name: .improveWriting)
                }

                HStack {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Correction History")
                            .font(.headline)
                        Text("\(historyCount) items in history")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if !showingClearConfirmation {
                        Button("Clear History") {
                            showingClearConfirmation = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(.vertical, 4)

                if showingClearConfirmation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Are you sure you want to clear all \(historyCount) correction records? This action cannot be undone.")
                            .font(.caption)
                        HStack {
                            Button("Cancel") {
                                showingClearConfirmation = false
                            }
                            Button("Clear") {
                                historyStore?.clearHistory()
                                refreshHistoryCount()
                                showingClearConfirmation = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                }

                HStack {
                    Button("Save") {
                        SettingsManager.setAIApiToken(token: openAIKey)
                        SettingsManager.setAIUrl(url: apiUrl)
                        SettingsManager.setAIModel(model: model)
                        SettingsManager.setLaunchAtLogin(enabled: launchAtLogin)

                        appState.checkPreconditions()
                        appState.showSettingsUI = false
                    }
                }
            } else {
                Button("Settings") {
                    appState.showSettingsUI = true
                }
            }
        }
        .onChange(of: appState.showSettingsUI) { _, newValue in
            if newValue {
                initializeStoreAndRefresh()
            }
        }
        .onAppear {
            initializeStoreAndRefresh()
        }
    }

    @MainActor
    private func initializeStoreAndRefresh() {
        // Initialize store if needed
        if historyStore == nil,
           let container = try? modelContext.container {
            historyStore = HistoryStore(modelContainer: container)
        }
        refreshHistoryCount()
    }

    @MainActor
    private func refreshHistoryCount() {
        if let store = historyStore {
            historyCount = store.getRecordCount(language: nil)
        }
    }
}

#Preview {
    SettingsUI(appState: AppState())
        .frame(width: 300, height: 200)
}
