import SwiftUI
import ApplicationServices
import Cocoa

@main
struct GrammifyAIApp: App {
    private var selectionManager = SelectionManager()
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow
    @State var observer: NSKeyValueObservation?

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentUI(appState: appState)
                .onAppear {
                    observer = NSApplication.shared.observe(\.keyWindow) { x, y in
                        if NSApplication.shared.keyWindow != nil {
                            appState.checkPreconditions()
                        }
                    }
                }
        } label: {
            Image(systemName: "wand.and.stars")
        }.menuBarExtraStyle(.window)

        Window("Suggestion", id: "suggestion") {
            SuggestionUI(appState: appState)
        }

        .onChange(of: appState.showSuggestionUI, initial: true) { oldState, newState in
            if (newState) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "suggestion")
            }
        }
    }
}
