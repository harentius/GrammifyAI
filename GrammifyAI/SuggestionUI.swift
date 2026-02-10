import SwiftUI
import SwiftData

struct SuggestionUI: View {
    @StateObject var appState: AppState
    @Environment(\.controlActiveState) var controlActiveState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var historyStore: HistoryStore?
    var llmClient = LlmClient()

    var body: some View {
        VStack(alignment: .leading) {
            if (appState.isAccessibilityAPIError) {
                Text(appState.accessibilityAPIError)
                    .foregroundStyle(.red)
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
        .onChange(of: appState.originalText, initial: true) { oldState, newState in

            if appState.preventAPIInteraction {
                return
            }

            appState.cleanOpenAIRequestState()

            Task {
                appState.isOpenAIRequestPending = true
                let result = await llmClient.correctWritting(text: newState)
                appState.isOpenAIRequestPending = false

                if result.isSuccessful() {
                    appState.suggestion = result.output
                    appState.detectedErrors = result.errors
                    appState.detectedLanguage = result.detectedLanguage
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.suggestion, forType: .string)

                    // Save to history with detected language
                    await saveToHistory(
                        originalText: newState,
                        correctedText: result.output,
                        errors: result.errors,
                        language: result.detectedLanguage.isEmpty ? "Unknown" : result.detectedLanguage
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
        if historyStore == nil,
           let container = try? modelContext.container {
            historyStore = HistoryStore(modelContainer: container)
        }

        // Save the record
        historyStore?.createRecord(
            originalText: originalText,
            correctedText: correctedText,
            errors: errors,
            language: language
        )
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

