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
    
    @Published var selectedTextNotFound = false

    init() {
        checkPreconditions()
        KeyboardShortcuts.onKeyDown(for: .improveWriting) { [self] in
            var selectionManager = SelectionManager()
            let text = selectionManager.getSelectedText()

            selectedTextNotFound = false
            showSuggestionUI = true

            if text == nil {
                selectedTextNotFound = true
                return
            }

            originalText = text!
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
