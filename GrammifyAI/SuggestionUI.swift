import SwiftUI
import SwiftData

struct SuggestionUI: View {
    @StateObject var appState: AppState
    @Environment(\.controlActiveState) var controlActiveState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var historyStore: HistoryStore?
    @State private var currentTask: Task<Void, Never>?
    var llmClient = LlmClient()

    var body: some View {
        VStack(alignment: .leading) {
            if (appState.isAccessibilityAPIError) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(appState.accessibilityAPIError)
                        .foregroundStyle(.red)

                    if !appState.accessibilityAPIPermissionSetUp {
                        HStack(spacing: 8) {
                            Button("Grant Accessibility Permission") {
                                appState.requestAccessibilityPermission()
                            }
                            Button("Open System Settings") {
                                appState.openAccessibilitySettings()
                            }
                        }
                    }
                }
            } else if (appState.isOpenAIError) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.openAIError)
                        .foregroundColor(.red)
                        .font(.headline)
                    if !appState.errorDetails.isEmpty {
                        Text("Server Response:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        ScrollView {
                            Text(appState.errorDetails)
                                .foregroundColor(.gray)
                                .font(.footnote)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 200)
                    }
                }
            } else if (appState.isOpenAIRequestPending) {
                Text("API request...").foregroundStyle(.blue)
            } else {
                Text(appState.originalText).foregroundStyle(.yellow)
                Divider()

                Text(DiffChecker.diffCheck(incorrectString: appState.originalText, correctString: appState.suggestion))
                Divider()

                Text("Suggestion is copied to the clipboard")
                    .italic()
                    .foregroundColor(.gray)
            }
        }.padding()
        .frame(minWidth: 600, minHeight: 300)
        .onChange(of: controlActiveState) { oldState, newState in
            if newState == .inactive {
                appState.showSuggestionUI = false
                dismiss()
            }
        }
        .onChange(of: appState.requestID, initial: true) { oldState, newState in
            if appState.preventAPIInteraction || appState.isAccessibilityAPIError {
                return
            }

            let textToCheck = appState.originalText
            guard !textToCheck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }

            guard appState.lastProcessedRequestID != newState else {
                return
            }
            appState.lastProcessedRequestID = newState

            currentTask?.cancel()
            appState.cleanOpenAIRequestState()

            currentTask = Task {
                appState.isOpenAIRequestPending = true
                let result = await llmClient.correctWritting(text: textToCheck)
                guard !Task.isCancelled else { return }
                appState.isOpenAIRequestPending = false

                if result.isSuccessful() {
                    appState.suggestion = result.output
                    appState.detectedErrors = result.errors
                    appState.detectedLanguage = result.detectedLanguage
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.suggestion, forType: .string)

                    // Save to history with detected language
                    saveToHistory(
                        originalText: textToCheck,
                        correctedText: result.output,
                        errors: result.errors,
                        language: result.detectedLanguage.isEmpty ? "unknown" : result.detectedLanguage
                    )
                } else {
                    appState.isOpenAIError = true
                    appState.openAIError = result.error
                    appState.errorDetails = result.errorDetails
                }
            }
        }
    }

    @MainActor
    private func saveToHistory(
        originalText: String,
        correctedText: String,
        errors: [CorrectionError],
        language: String
    ) {
        // Initialize store if needed
        if historyStore == nil {
            historyStore = HistoryStore(modelContainer: modelContext.container)
        }

        // Save the record
        historyStore?.createRecord(
            originalText: originalText,
            correctedText: correctedText,
            errors: errors,
            language: language
        )
        appState.historyVersion += 1
    }
}

#Preview {
    let appState = AppState()
    appState.originalText = "I a supor original text"
    appState.suggestion = "I am corrected text"
    appState.isOpenAIRequestPending = false
    appState.preventAPIInteraction = true

    return SuggestionUI(appState: appState)
        .frame(width: 600, height: 300)
}

