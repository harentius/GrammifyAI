import SwiftUI

struct MenuBarContentUI: View {
    @StateObject var appState: AppState
    @ObservedObject var checkForUpdatesViewModel: CheckForUpdatesViewModel

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

                Button("Check for Updates...") {
                    checkForUpdatesViewModel.checkForUpdates()
                }
                .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
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

    return MenuBarContentUI(appState: appState, checkForUpdatesViewModel: CheckForUpdatesViewModel())
        .frame(width: 300, height: 200)
}
