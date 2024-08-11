import SwiftUI
import KeyboardShortcuts

struct SettingsUI: View {
    @StateObject var appState: AppState
    @State private var openAIKey: String = ""

    var body: some View {
        VStack(alignment: .leading) {
            if appState.showSettingsUI {
                HStack {
                    Text("Your OpenAI API key")
                    SecureField("OpenAI API key", text: $openAIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                }

                Form {
                    KeyboardShortcuts.Recorder("Improve writing:", name: .improveWriting)
                }

                Button("Close") {
                    if !openAIKey.isEmpty {
                        SettingsManager.setOpenAIToken(token: openAIKey)
                    }

                    appState.checkPreconditions()
                    appState.showSettingsUI = false
                }
            } else {
                Button("Settings") {
                    appState.showSettingsUI = true
                }
            }
        }
    }
}

#Preview {
    SettingsUI(appState: AppState())
        .frame(width: 300, height: 200)
}
