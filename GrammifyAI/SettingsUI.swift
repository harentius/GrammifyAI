import SwiftUI
import KeyboardShortcuts

struct SettingsUI: View {
    @StateObject var appState: AppState
    @State private var apiUrl: String = SettingsManager.getAIUrl()
    @State private var model: String = SettingsManager.getAIModel()
    @State private var openAIKey: String = SettingsManager.getAIApiToken()

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
                    Button("Close") {
                        SettingsManager.setAIApiToken(token: openAIKey)
                        SettingsManager.setAIUrl(url: apiUrl)
                        SettingsManager.setAIModel(model: model)

                        //Task {
                        //    let openAIHelper = OpenAIHelper()
                        //    let result = await openAIHelper.correctWritting(text: "test")
                        //}
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
    }
}

#Preview {
    SettingsUI(appState: AppState())
        .frame(width: 300, height: 200)
}
