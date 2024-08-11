import SwiftUI

struct PreconditionsUI: View {
    @StateObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading) {
            if !appState.showSettingsUI {
                if !appState.openAIKeySetUp {
                    Text("Please enter you OpenAI key in Settings")
                        .foregroundStyle(.red)
                        .padding([.bottom], 10)
                }

                if !appState.accessibilityAPIPermissionSetUp {
                    Text("Please add GrammifyAI access to Accessibility API")
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

#Preview {
    let appState = AppState()
    appState.openAIKeySetUp = false

    return PreconditionsUI(appState: appState)
        .frame(width: 300, height: 200)
}
