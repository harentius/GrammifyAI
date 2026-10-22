import Foundation
import KeyboardShortcuts
import AppKit
import ApplicationServices

final class AppState: ObservableObject {
    // preconditions
    @Published var accessibilityAPIPermissionSetUp = false
    @Published var openAIKeySetUp = false

    // UI state
    @Published var showSettingsUI = false
    @Published var showSuggestionUI = false
    @Published var showStatisticsUI = false

    @Published var originalText = ""
    @Published var suggestion = ""
    @Published var detectedErrors: [CorrectionError] = []
    @Published var detectedLanguage: String = ""
    @Published var requestID: UUID = UUID()
    var lastProcessedRequestID: UUID? = nil
    @Published var historyVersion: Int = 0

    @Published var isOpenAIRequestPending = false
    @Published var isOpenAIError = false
    @Published var openAIError = ""
    @Published var errorDetails: String = ""
    @Published var preventAPIInteraction = false

    @Published var isAccessibilityAPIError = false
    @Published var accessibilityAPIError = ""

    private var accessibilityPollTimer: Timer?

    private static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    init() {
        checkPreconditions()

        if !accessibilityAPIPermissionSetUp && !Self.isRunningInPreview {
            requestAccessibilityPermission()
        }

        KeyboardShortcuts.onKeyDown(for: .improveWriting) { [self] in
            isAccessibilityAPIError = false
            accessibilityAPIError = ""

            let selectionManager = SelectionManager()
            let selectedTextResult = selectionManager.getSelectedText()

            if selectedTextResult.isSuccessful() {
                originalText = selectedTextResult.output
                requestID = UUID()
            } else {
                originalText = ""
                isAccessibilityAPIError = true
                accessibilityAPIError = selectedTextResult.error
                checkPreconditions()
            }

            showSuggestionUI = true
        }
    }

    deinit {
        accessibilityPollTimer?.invalidate()
    }

    public func checkPreconditions() {
        let openAIToken = SettingsManager.getAIApiToken()
        openAIKeySetUp = !openAIToken.isEmpty

        let trusted = AXIsProcessTrusted()
        accessibilityAPIPermissionSetUp = trusted

        if trusted {
            stopAccessibilityPolling()
        } else if !Self.isRunningInPreview {
            startAccessibilityPolling()
        }
    }

    /// Resets any stale TCC Accessibility entry (e.g. from a previous ad-hoc signed version)
    /// and triggers the native macOS Accessibility permission prompt.
    public func requestAccessibilityPermission() {
        if AXIsProcessTrusted() {
            accessibilityAPIPermissionSetUp = true
            stopAccessibilityPolling()
            return
        }

        resetAccessibilityTCCEntry()

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        accessibilityAPIPermissionSetUp = trusted

        if !trusted {
            startAccessibilityPolling()
        }
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startAccessibilityPolling()
    }

    private func resetAccessibilityTCCEntry() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleId]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            NSLog("Failed to reset Accessibility TCC entry: \(error.localizedDescription)")
        }
    }

    private func startAccessibilityPolling() {
        guard accessibilityPollTimer == nil else { return }
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let trusted = AXIsProcessTrusted()
            if trusted != self.accessibilityAPIPermissionSetUp {
                DispatchQueue.main.async {
                    self.accessibilityAPIPermissionSetUp = trusted
                    if trusted {
                        self.isAccessibilityAPIError = false
                        self.accessibilityAPIError = ""
                        self.stopAccessibilityPolling()
                    }
                }
            }
        }
    }

    private func stopAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
    }

    public func cleanOpenAIRequestState() {
        isOpenAIRequestPending = false
        isOpenAIError = false
        openAIError = ""
        errorDetails = ""
        detectedErrors = []
        detectedLanguage = ""
    }
}
