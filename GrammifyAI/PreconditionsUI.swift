import SwiftUI

struct PreconditionsUI: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading) {
            if !appState.showSettingsUI {
                if !appState.openAIKeySetUp {
                    Text("Please enter you OpenAI key in Settings")
                        .foregroundStyle(.red)
                        .padding([.bottom], 10)
                }

                if !appState.accessibilityAPIPermissionSetUp {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Please grant GrammifyAI access to Accessibility API")
                            .foregroundStyle(.red)

                        HStack(spacing: 8) {
                            Button("Grant Permission") {
                                appState.requestAccessibilityPermission()
                            }
                            Button("Open System Settings") {
                                appState.openAccessibilitySettings()
                            }
                        }
                    }
                    .padding([.bottom], 10)
                }
            }
        }
    }
}

#Preview {
    let appState = AppState()
    appState.openAIKeySetUp = false
    appState.accessibilityAPIPermissionSetUp = false

    return PreconditionsUI(appState: appState)
        .frame(width: 300, height: 200)
}
