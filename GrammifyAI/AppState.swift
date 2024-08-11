import Foundation
import KeyboardShortcuts
import AppKit
import OpenAI

final class AppState: ObservableObject {
    // preconditions
    @Published var accessibilityAPIPermissionSetUp = false
    @Published var openAIKeySetUp = false

    // UI state
    @Published var showSettingsUI = false
    @Published var showSuggestionUI = false

    @Published var originalText = ""
    @Published var suggestion = ""

    @Published var isOpenAIRequestPending = false
    @Published var isOpenAIError = false
    @Published var openAIError = ""

    @Published var isAccessibilityAPIError = false
    @Published var accessibilityAPIError = ""

    init() {
        checkPreconditions()
        KeyboardShortcuts.onKeyDown(for: .improveWriting) { [self] in
            var selectionManager = SelectionManager()
            let selectedTextResult = selectionManager.getSelectedText()

            if selectedTextResult.isSuccessful() {
                originalText = selectedTextResult.output
            } else {
                isAccessibilityAPIError = true
                accessibilityAPIError = selectedTextResult.error
            }

            showSuggestionUI = true
        }
    }

    public func checkPreconditions() {
        let openAIToken = SettingsManager.getOpenAIToken()
        openAIKeySetUp = openAIToken != nil && !openAIToken!.isEmpty

        accessibilityAPIPermissionSetUp = AXIsProcessTrusted()
    }

    public func cleanOpenAIRequestState() {
        isOpenAIRequestPending = false
        isOpenAIError = false
        openAIError = ""
    }
}
