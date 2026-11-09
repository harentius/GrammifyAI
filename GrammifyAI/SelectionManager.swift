import Foundation
import ApplicationServices
import AppKit

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

    /// Returns the screen rectangle (in AppKit bottom-left screen coordinates) of the currently
    /// selected text via the Accessibility API, falling back to the current mouse cursor location
    /// when an application (such as Electron/Chromium apps) does not report selection bounds.
    func getSelectionAnchorRect() -> CGRect {
        var focusedUIElement: AnyObject?
        let focusedError = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedUIElement
        )

        if focusedError == .success, let elementRef = focusedUIElement {
            let element = elementRef as! AXUIElement
            var rangeValue: AnyObject?
            let rangeError = AXUIElementCopyAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                &rangeValue
            )

            if rangeError == .success,
               let rangeRef = rangeValue,
               CFGetTypeID(rangeRef) == AXValueGetTypeID() {
                let axRange = rangeRef as! AXValue
                var boundsValue: AnyObject?
                let boundsError = AXUIElementCopyParameterizedAttributeValue(
                    element,
                    kAXBoundsForRangeParameterizedAttribute as CFString,
                    axRange,
                    &boundsValue
                )

                if boundsError == .success,
                   let boundsRef = boundsValue,
                   CFGetTypeID(boundsRef) == AXValueGetTypeID() {
                    let axBounds = boundsRef as! AXValue
                    var cgRect = CGRect.zero
                    if AXValueGetValue(axBounds, .cgRect, &cgRect),
                       !cgRect.isNull,
                       !cgRect.isInfinite,
                       (cgRect.width > 0 || cgRect.height > 0),
                       cgRect.origin != .zero {
                        let primaryScreenHeight = NSScreen.screens.first?.frame.height
                            ?? NSScreen.main?.frame.height
                            ?? 0
                        let cocoaY = primaryScreenHeight - cgRect.origin.y - cgRect.size.height
                        return CGRect(
                            x: cgRect.origin.x,
                            y: cocoaY,
                            width: cgRect.size.width,
                            height: cgRect.size.height
                        )
                    }
                }
            }
        }

        return CGRect(origin: NSEvent.mouseLocation, size: .zero)
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
