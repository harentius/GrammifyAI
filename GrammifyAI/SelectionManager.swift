import Foundation
import ApplicationServices
import AppKit
import Carbon.HIToolbox

struct SelectionTarget {
    let application: NSRunningApplication?
    let focusedElement: AXUIElement?
}

struct SelectionManager {
    var systemWideElement = AXUIElementCreateSystemWide()

    func getSelectedText() -> Result {
        return getSelectedTextWithTarget().result
    }

    func getSelectedTextWithTarget() -> (result: Result, target: SelectionTarget) {
        let frontmostApp = NSWorkspace.shared.frontmostApplication

        var focusedUIElement: AnyObject?
        let focusedUIElementErrorCode = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedUIElement
        )

        if focusedUIElementErrorCode != .success {
            return (
                Result.error(error: Self.describeError(code: focusedUIElementErrorCode, context: "focused element")),
                SelectionTarget(application: frontmostApp, focusedElement: nil)
            )
        }

        let element = focusedUIElement as! AXUIElement
        var pid: pid_t = 0
        let resolvedApp: NSRunningApplication?
        if AXUIElementGetPid(element, &pid) == .success,
           let elementApp = NSRunningApplication(processIdentifier: pid) {
            resolvedApp = elementApp
        } else {
            resolvedApp = frontmostApp
        }

        var selectedTextElement: AnyObject?
        let selectedTextElementErrorCode = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextElement
        )

        if selectedTextElementErrorCode != .success {
            return (
                Result.error(error: Self.describeError(code: selectedTextElementErrorCode, context: "selected text")),
                SelectionTarget(application: resolvedApp, focusedElement: element)
            )
        }

        return (
            Result.success(output: selectedTextElement as! String),
            SelectionTarget(application: resolvedApp, focusedElement: element)
        )
    }

    /// Replaces the selected text in the source application using a two-tier strategy:
    /// Tier 1: Direct Accessibility write via `kAXSelectedTextAttribute` (verified against `kAXValueAttribute`).
    /// Tier 2: Re-activating the source app and posting a synthesized `⌘ + V` key event.
    func replaceSelectedText(with replacement: String, in target: SelectionTarget?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(replacement, forType: .string)

        let sourceApp = target?.application
        let element = target?.focusedElement

        if let sourceApp = sourceApp {
            NSApplication.shared.yieldActivation(to: sourceApp)
            sourceApp.activate(options: [.activateIgnoringOtherApps])
        }

        Self.waitForAppActivation(sourceApp, attemptsRemaining: 20) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let element = element,
                   Self.tryAccessibilityReplacement(replacement, on: element, app: sourceApp) {
                    return
                }
                Self.postPasteShortcut()
            }
        }
    }

    private static func waitForAppActivation(
        _ app: NSRunningApplication?,
        attemptsRemaining: Int,
        completion: @escaping () -> Void
    ) {
        guard let app = app else {
            completion()
            return
        }

        if app.isActive || attemptsRemaining <= 0 {
            completion()
            return
        }

        app.activate(options: [.activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            waitForAppActivation(app, attemptsRemaining: attemptsRemaining - 1, completion: completion)
        }
    }

    private static func tryAccessibilityReplacement(
        _ replacement: String,
        on element: AXUIElement,
        app: NSRunningApplication?
    ) -> Bool {
        if isWebOrElectronContext(element: element, app: app) {
            return false
        }

        guard let role = copyStringAttribute(kAXRoleAttribute as CFString, from: element),
              role == (kAXTextFieldRole as String) || role == (kAXTextAreaRole as String) else {
            return false
        }

        guard let beforeSelected = copyStringAttribute(kAXSelectedTextAttribute as CFString, from: element),
              !beforeSelected.isEmpty,
              let beforeValue = copyStringAttribute(kAXValueAttribute as CFString, from: element) else {
            return false
        }

        if beforeSelected == replacement {
            return true
        }

        var isSettable = DarwinBoolean(false)
        let settableError = AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &isSettable
        )
        guard settableError == .success && isSettable.boolValue else {
            return false
        }

        let setError = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            replacement as CFTypeRef
        )
        guard setError == .success else {
            return false
        }

        guard let afterValue = copyStringAttribute(kAXValueAttribute as CFString, from: element),
              afterValue != beforeValue,
              afterValue.contains(replacement) else {
            return false
        }

        return true
    }

    private static func isWebOrElectronContext(element: AXUIElement, app: NSRunningApplication?) -> Bool {
        if let bundleURL = app?.bundleURL {
            let electronFrameworkURL = bundleURL
                .appendingPathComponent("Contents/Frameworks/Electron Framework.framework")
            if FileManager.default.fileExists(atPath: electronFrameworkURL.path) {
                return true
            }
        }

        var current: AXUIElement? = element
        for _ in 0..<15 {
            guard let node = current else { break }
            if let role = copyStringAttribute(kAXRoleAttribute as CFString, from: node),
               role == "AXWebArea" {
                return true
            }

            var parentRef: AnyObject?
            let parentError = AXUIElementCopyAttributeValue(
                node,
                kAXParentAttribute as CFString,
                &parentRef
            )
            if parentError == .success, let parent = parentRef {
                current = (parent as! AXUIElement)
            } else {
                break
            }
        }

        return false
    }

    private static func copyStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var value: AnyObject?
        let error = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard error == .success, let stringValue = value as? String else {
            return nil
        }
        return stringValue
    }

    private static func postPasteShortcut() {
        let source = CGEventSource(stateID: .privateState)
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
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
