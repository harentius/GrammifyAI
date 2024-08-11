import Foundation
import ApplicationServices

struct SelectionManager {
    var systemWideElement = AXUIElementCreateSystemWide()

    func getSelectedText() -> String? {
        var focusedUIElement: AnyObject?
        let focusedUIElementErrorCode = AXUIElementCopyAttributeValue(systemWideElement as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedUIElement)

        if focusedUIElementErrorCode != .success {
            // TODO
            return nil
        }

        var selectedTextElement: AnyObject?
        let selectedTextElementErrorCode = AXUIElementCopyAttributeValue(focusedUIElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextElement)

        if selectedTextElementErrorCode != .success {
            // TODO
            return nil
        }

        return selectedTextElement as? String
    }
}
