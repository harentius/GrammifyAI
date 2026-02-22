import Foundation
import ApplicationServices

struct SelectionManager {
    var systemWideElement = AXUIElementCreateSystemWide()

    func getSelectedText() -> Result {
        var focusedUIElement: AnyObject?
        let focusedUIElementErrorCode = AXUIElementCopyAttributeValue(systemWideElement as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedUIElement)

        if focusedUIElementErrorCode != .success {
            return Result.error(error: Self.describeError(code: focusedUIElementErrorCode, context: "focused element"))
        }

        var selectedTextElement: AnyObject?
        let selectedTextElementErrorCode = AXUIElementCopyAttributeValue(focusedUIElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextElement)

        if selectedTextElementErrorCode != .success {
            return Result.error(error: Self.describeError(code: selectedTextElementErrorCode, context: "selected text"))
        }

        return Result.success(output: selectedTextElement as! String)
    }

    private static func describeError(code: AXError, context: String) -> String {
        switch code {
        case .apiDisabled:
            return "Accessibility API is disabled. Please add GrammifyAI to System Settings → Privacy & Security → Accessibility."
        case .noValue:
            return "No text is selected. Please select some text and try again."
        case .attributeUnsupported, .notImplemented:
            return "The current application does not support text selection via Accessibility API."
        case .cannotComplete:
            return "Could not read \(context). The application may be busy or unresponsive. Please try again."
        case .invalidUIElement:
            return "Could not read \(context). The focused element is no longer valid. Please try again."
        default:
            return "Could not read \(context). Accessibility error: \(code.valueAsString)"
        }
    }
}
