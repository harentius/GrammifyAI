import SwiftUI
import ApplicationServices
import Cocoa
import SwiftData

@main
struct GrammifyAIApp: App {
    private var selectionManager = SelectionManager()
    @StateObject private var appState = AppState()
    @StateObject private var checkForUpdatesViewModel = CheckForUpdatesViewModel()
    @Environment(\.openWindow) private var openWindow
    @State var observer: NSKeyValueObservation?

    // SwiftData model container for correction history
    let modelContainer: ModelContainer = {
        let schema = Schema([
            CorrectionRecord.self,
            CorrectionError.self
        ])
        let storeURL = Self.resolveStoreURL()
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: GrammifyMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private static func resolveStoreURL() -> URL {
        let fileManager = FileManager.default
        guard let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not locate Application Support directory")
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "harentius.GrammifyAI"
        let appDirectory = appSupportDir.appendingPathComponent(bundleID, isDirectory: true)

        do {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        } catch {
            NSLog("Failed to create application support directory: \(error.localizedDescription)")
        }

        let storeURL = appDirectory.appendingPathComponent("GrammifyAI.store")

        // One-time migration from legacy shared ~/Library/Application Support/default.store
        if !fileManager.fileExists(atPath: storeURL.path) {
            let legacyStoreURL = appSupportDir.appendingPathComponent("default.store")
            if fileManager.fileExists(atPath: legacyStoreURL.path) {
                do {
                    try fileManager.copyItem(at: legacyStoreURL, to: storeURL)
                    for suffix in ["-wal", "-shm"] {
                        let legacySidecar = URL(fileURLWithPath: legacyStoreURL.path + suffix)
                        let newSidecar = URL(fileURLWithPath: storeURL.path + suffix)
                        if fileManager.fileExists(atPath: legacySidecar.path) {
                            try fileManager.copyItem(at: legacySidecar, to: newSidecar)
                        }
                    }
                    NSLog("Migrated SwiftData store from \(legacyStoreURL.path) to \(storeURL.path)")
                } catch {
                    NSLog("Failed to migrate legacy SwiftData store: \(error.localizedDescription)")
                    // Clean up partial copy if main or sidecar copy failed so ModelContainer starts cleanly
                    for suffix in ["", "-wal", "-shm"] {
                        try? fileManager.removeItem(atPath: storeURL.path + suffix)
                    }
                }
            }
        }

        return storeURL
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentUI(appState: appState, checkForUpdatesViewModel: checkForUpdatesViewModel)
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

        Window("Suggestion", id: "suggestion") {
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
        .onChange(of: appState.windowPositionToken) { _, _ in
            if appState.showSuggestionUI {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "suggestion")
            }
        }

        Window("Statistics", id: "statistics") {
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
