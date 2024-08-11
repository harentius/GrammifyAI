import Foundation
import ApplicationServices

struct SelectionManager {
    var systemWideElement = AXUIElementCreateSystemWide()

    func getSelectedText() -> Result {
        var focusedUIElement: AnyObject?
        let focusedUIElementErrorCode = AXUIElementCopyAttributeValue(systemWideElement as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedUIElement)

        if focusedUIElementErrorCode != .success {
            return Result.error(error: "Accessibility API access issue: Can't read focusedUIElement. Code: " + focusedUIElementErrorCode.valueAsString)
        }

        var selectedTextElement: AnyObject?
        let selectedTextElementErrorCode = AXUIElementCopyAttributeValue(focusedUIElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextElement)

        if selectedTextElementErrorCode != .success {
            return Result.error(error: "Accessibility API access issue: Can't read Selected Text Element. Code: " + selectedTextElementErrorCode.valueAsString)
        }

        return Result.success(output: selectedTextElement as! String)
    }
}
