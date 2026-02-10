import SwiftUI
import ApplicationServices
import Cocoa
import SwiftData

@main
struct GrammifyAIApp: App {
    private var selectionManager = SelectionManager()
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow
    @State var observer: NSKeyValueObservation?

    // SwiftData model container for correction history
    let modelContainer: ModelContainer = {
        let schema = Schema([
            CorrectionRecord.self,
            CorrectionError.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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
                .modelContainer(modelContainer)
        } label: {
            Image(systemName: "wand.and.stars")
        }.menuBarExtraStyle(.window)

        WindowGroup("Suggestion", id: "suggestion") {
            SuggestionUI(appState: appState)
                .modelContainer(modelContainer)
        }
        .windowResizability(.contentSize)
        .commandsRemoved()
        .onChange(of: appState.showSuggestionUI, initial: true) { oldState, newState in
            if (newState) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "suggestion")
            }
        }

        WindowGroup("Statistics", id: "statistics") {
            StatisticsUI(appState: appState)
                .modelContainer(modelContainer)
        }
        .commandsRemoved()
        .onChange(of: appState.showStatisticsUI, initial: true) { oldState, newState in
            if (newState) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "statistics")
            }
        }
    }
}
