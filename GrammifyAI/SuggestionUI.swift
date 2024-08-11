import SwiftUI

//let suggestion = OpenAIHelper.correctWritting(text: te) { result in
//    NSPasteboard.general.clearContents() // Clear existing content
//    NSPasteboard.general.setString(result.output, forType: .string)
//}


struct SuggestionUI: View {
    @StateObject var appState: AppState
    @Environment(\.controlActiveState) var controlActiveState
    var openAIHelper = OpenAIHelper()

    var body: some View {
        VStack(alignment: .leading) {
            if (appState.selectedTextNotFound) {
                Text("Can't read your text selection")
                    .foregroundStyle(.red)
            } else if (appState.isOpenAIError) {
                Text(appState.openAIError).foregroundStyle(.red)
            } else if (appState.isOpenAIRequestPending) {
                Text("OpenAPI request...").foregroundStyle(.blue)
            } else {
                Text(appState.originalText).foregroundStyle(.yellow)
                Divider()
                Text(appState.suggestion).foregroundStyle(.green)
                Divider()
                Text("Suggestion is copied to the clipboard").italic()
            }
        }.padding()
        .onChange(of: controlActiveState, initial: true) { oldState, newState in
            if newState == .inactive {
                appState.showSuggestionUI = false
            }
        }
        .onChange(of: appState.originalText, initial: true) { oldState, newState in
            appState.cleanOpenAIRequestState()

            Task {
                appState.isOpenAIRequestPending = true
                let result = await openAIHelper.correctWritting(text: newState)
                appState.isOpenAIRequestPending = false

                if result.status == Result.STATUS_SUCCESS {
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
    appState.selectedTextNotFound = false
    appState.originalText = "I a original text"
    appState.suggestion = "I am corrected text"
    appState.isOpenAIRequestPending = true

    return SuggestionUI(appState: appState)
        .frame(width: 600, height: 300)
}
