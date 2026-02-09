import SwiftUI

struct MenuBarContentUI: View {
    @StateObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("GrammifyAI")
                Text("\(getAppVersion())")
                    .foregroundColor(.gray)
            }
            Divider().padding([.bottom], 10)

            PreconditionsUI(appState: appState)

            SettingsUI(appState: appState)

            if !appState.showSettingsUI {
                Button("Statistics") {
                    appState.showStatisticsUI = true
                }
            }

            Divider()

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }.padding()
    }

    func getAppVersion() -> String {
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return appVersion
        }
        return "Unknown"
    }
}

#Preview {
    let appState = AppState()
    appState.openAIKeySetUp = false

    return MenuBarContentUI(appState: appState)
        .frame(width: 300, height: 200)
}
