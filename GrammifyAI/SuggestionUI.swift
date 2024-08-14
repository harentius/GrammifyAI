import SwiftUI

struct SuggestionUI: View {
    @StateObject var appState: AppState
    @Environment(\.controlActiveState) var controlActiveState
    var openAIHelper = OpenAIHelper()

    var body: some View {
        VStack(alignment: .leading) {
            if (appState.isAccessibilityAPIError) {
                Text(appState.accessibilityAPIError)
                    .foregroundStyle(.red)
            } else if (appState.isOpenAIError) {
                Text(appState.openAIError).foregroundStyle(.red)
            } else if (appState.isOpenAIRequestPending) {
                Text("OpenAPI request...").foregroundStyle(.blue)
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
        .onChange(of: controlActiveState, initial: true) { oldState, newState in
            if newState == .inactive {
                appState.showSuggestionUI = false
            }
        }
        .onChange(of: appState.originalText, initial: true) { oldState, newState in

            if appState.preventAPIInteraction {
                return
            }

            appState.cleanOpenAIRequestState()

            Task {
                appState.isOpenAIRequestPending = true
                let result = await openAIHelper.correctWritting(text: newState)
                appState.isOpenAIRequestPending = false

                if result.isSuccessful() {
                    appState.suggestion = result.output
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.suggestion, forType: .string)
                } else {
                    appState.isOpenAIError = true
                    appState.openAIError = result.error
                }
            }
        }
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
