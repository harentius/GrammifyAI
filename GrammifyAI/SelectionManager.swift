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
        let frontmostApp = Self.resolveFrontmostSourceApplication()

        if !AXIsProcessTrusted() {
            return (
                Result.error(error: Self.describeError(code: .apiDisabled, context: "focused element")),
                SelectionTarget(application: frontmostApp, focusedElement: nil)
            )
        }

        if let pid = frontmostApp?.processIdentifier {
            Self.enableManualAccessibilityIfNeeded(for: pid, app: frontmostApp)
        }

        let focusedElement = Self.copyFocusedUIElement(
            systemWideElement: systemWideElement,
            frontmostApp: frontmostApp
        )

        var resolvedApp = frontmostApp
        if let element = focusedElement {
            var pid: pid_t = 0
            if AXUIElementGetPid(element, &pid) == .success,
               pid != ProcessInfo.processInfo.processIdentifier,
               let elementApp = NSRunningApplication(processIdentifier: pid) {
                resolvedApp = elementApp
            }
        }

        let target = SelectionTarget(application: resolvedApp, focusedElement: focusedElement)

        // Tier 1: Read selected text via Accessibility API (standard attribute or text marker range)
        var axErrorCode: AXError = .noValue
        if let element = focusedElement {
            if let axText = Self.copySelectedTextViaAccessibility(from: element, errorCode: &axErrorCode),
               !axText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (Result.success(output: axText), target)
            }

            // If this is a standard native text control whose selection range is explicitly 0-length,
            // do not synthesize Cmd+C (which would cause a system beep with nothing selected).
            if Self.isExplicitlyEmptyNativeSelection(element: element, app: resolvedApp) {
                return (
                    Result.error(error: Self.describeError(code: .noValue, context: "selected text")),
                    target
                )
            }
        }

        // Tier 2: Fallback to synthesized Cmd+C copy (for VS Code, Electron/Chromium apps, terminals, etc.)
        switch Self.copySelectedTextViaClipboard() {
        case .copied(let copiedText):
            return (Result.success(output: copiedText), target)
        case .emptySelection:
            return (
                Result.error(error: Self.describeError(code: .noValue, context: "selected text")),
                target
            )
        case .failed:
            let fallbackCode: AXError = (focusedElement == nil) ? .noValue : axErrorCode
            return (
                Result.error(error: Self.describeError(code: fallbackCode == .success ? .noValue : fallbackCode, context: "selected text")),
                target
            )
        }
    }

    /// Replaces the selected text in the source application using a two-tier strategy:
    /// Tier 1: Direct Accessibility write via `kAXSelectedTextAttribute` (verified against `kAXValueAttribute`).
    /// Tier 2: Re-activating the source app and posting a synthesized `⌘ + V` key event.
    func replaceSelectedText(with replacement: String, in target: SelectionTarget?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(replacement, forType: .string)

        let sourceApp = target?.application
        let element = target?.focusedElement
        let isWebOrElectron = Self.isWebOrElectronContext(element: element, app: sourceApp)

        if let sourceApp = sourceApp {
            NSApplication.shared.yieldActivation(to: sourceApp)
            sourceApp.activate(options: [.activateIgnoringOtherApps])
        }

        Self.waitForAppActivation(sourceApp, attemptsRemaining: 30) {
            let settleDelay: TimeInterval = isWebOrElectron ? 0.10 : 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) {
                if !isWebOrElectron,
                   let element = element,
                   Self.tryAccessibilityReplacement(replacement, on: element, app: sourceApp) {
                    return
                }
                Self.postPasteShortcut()
            }
        }
    }

    private static func resolveFrontmostSourceApplication() -> NSRunningApplication? {
        let currentPid = ProcessInfo.processInfo.processIdentifier
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != currentPid {
            return frontmost
        }
        return nil
    }

    private static func enableManualAccessibilityIfNeeded(for pid: pid_t, app: NSRunningApplication?) {
        let appElement = AXUIElementCreateApplication(pid)
        _ = AXUIElementSetAttributeValue(
            appElement,
            "AXManualAccessibility" as CFString,
            kCFBooleanTrue
        )
    }

    private static func copyFocusedUIElement(
        systemWideElement: AXUIElement,
        frontmostApp: NSRunningApplication?
    ) -> AXUIElement? {
        var focusedUIElement: AnyObject?
        let systemError = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedUIElement
        )
        if systemError == .success, let element = focusedUIElement {
            return (element as! AXUIElement)
        }

        if let pid = frontmostApp?.processIdentifier {
            let appElement = AXUIElementCreateApplication(pid)
            var appFocusedElement: AnyObject?
            let appError = AXUIElementCopyAttributeValue(
                appElement,
                kAXFocusedUIElementAttribute as CFString,
                &appFocusedElement
            )
            if appError == .success, let element = appFocusedElement {
                return (element as! AXUIElement)
            }
        }

        return nil
    }

    private static func copySelectedTextViaAccessibility(
        from element: AXUIElement,
        errorCode: inout AXError
    ) -> String? {
        var selectedTextElement: AnyObject?
        errorCode = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextElement
        )
        if errorCode == .success,
           let text = selectedTextElement as? String,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }

        // Fallback to WebKit/Chromium text marker range attribute if available
        var markerRangeRef: AnyObject?
        let markerRangeError = AXUIElementCopyAttributeValue(
            element,
            "AXSelectedTextMarkerRange" as CFString,
            &markerRangeRef
        )
        if markerRangeError == .success, let markerRange = markerRangeRef {
            var markerStringRef: AnyObject?
            let stringError = AXUIElementCopyParameterizedAttributeValue(
                element,
                "AXStringForTextMarkerRange" as CFString,
                markerRange,
                &markerStringRef
            )
            if stringError == .success,
               let markerText = markerStringRef as? String,
               !markerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorCode = .success
                return markerText
            }
        }

        return nil
    }

    private static func isExplicitlyEmptyNativeSelection(
        element: AXUIElement,
        app: NSRunningApplication?
    ) -> Bool {
        if isWebOrElectronContext(element: element, app: app) {
            return false
        }

        guard let role = copyStringAttribute(kAXRoleAttribute as CFString, from: element),
              role == (kAXTextFieldRole as String) || role == (kAXTextAreaRole as String) else {
            return false
        }

        guard copyStringAttribute(kAXValueAttribute as CFString, from: element) != nil else {
            return false
        }

        var rangeValue: AnyObject?
        let rangeError = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )
        guard rangeError == .success,
              let rangeRef = rangeValue,
              CFGetTypeID(rangeRef) == AXValueGetTypeID() else {
            return false
        }

        var cfRange = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &cfRange) else {
            return false
        }

        return cfRange.length == 0
    }

    private enum ClipboardCopyResult {
        case copied(String)
        case emptySelection
        case failed
    }

    private struct PasteboardItemSnapshot {
        let dataByType: [(NSPasteboard.PasteboardType, Data)]
    }

    private static func savePasteboardSnapshot(_ pasteboard: NSPasteboard) -> [PasteboardItemSnapshot] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            let pairs: [(NSPasteboard.PasteboardType, Data)] = item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
            return PasteboardItemSnapshot(dataByType: pairs)
        }
    }

    private static func restorePasteboardSnapshot(_ snapshot: [PasteboardItemSnapshot], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }
        let items: [NSPasteboardItem] = snapshot.compactMap { itemSnapshot in
            guard !itemSnapshot.dataByType.isEmpty else { return nil }
            let item = NSPasteboardItem()
            for (type, data) in itemSnapshot.dataByType {
                item.setData(data, forType: type)
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    private static func copySelectedTextViaClipboard() -> ClipboardCopyResult {
        let pasteboard = NSPasteboard.general
        let snapshot = savePasteboardSnapshot(pasteboard)
        let initialChangeCount = pasteboard.changeCount

        postCopyShortcut()

        var didChange = false
        for _ in 0..<25 {
            usleep(10_000) // 10ms per poll (up to 250ms total)
            if pasteboard.changeCount != initialChangeCount {
                didChange = true
                break
            }
        }

        guard didChange else {
            return .failed
        }

        // VS Code sets "vscode-editor-data" with {"isFromEmptySelection": true} when Cmd+C
        // copies the current line without any text actually selected.
        if isVSCodeEmptySelectionCopy(pasteboard) {
            restorePasteboardSnapshot(snapshot, to: pasteboard)
            return .emptySelection
        }

        let copiedText = pasteboard.string(forType: .string)
        restorePasteboardSnapshot(snapshot, to: pasteboard)

        guard let text = copiedText,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .emptySelection
        }

        return .copied(text)
    }

    private static func isVSCodeEmptySelectionCopy(_ pasteboard: NSPasteboard) -> Bool {
        let vsCodeType = NSPasteboard.PasteboardType("vscode-editor-data")
        guard let data = pasteboard.data(forType: vsCodeType),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let isFromEmptySelection = json["isFromEmptySelection"] as? Bool else {
            return false
        }
        return isFromEmptySelection
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

        let isFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
        if (app.isActive && isFrontmost) || attemptsRemaining <= 0 {
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

    private static func isWebOrElectronContext(element: AXUIElement?, app: NSRunningApplication?) -> Bool {
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

    private static func postCopyShortcut() {
        let source = CGEventSource(stateID: .privateState)
        let cKeyCode = CGKeyCode(kVK_ANSI_C)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        usleep(5_000)
        keyUp.post(tap: .cghidEventTap)
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
        usleep(5_000)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Returns the screen rectangle (in AppKit bottom-left screen coordinates) of the currently
    /// selected text via the Accessibility API, falling back to the current mouse cursor location
    /// when an application (such as Electron/Chromium apps) does not report selection bounds.
    func getSelectionAnchorRect() -> CGRect {
        let frontmostApp = Self.resolveFrontmostSourceApplication()
        if let element = Self.copyFocusedUIElement(
            systemWideElement: systemWideElement,
            frontmostApp: frontmostApp
        ) {
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
                var cfRange = CFRange(location: 0, length: 0)
                if AXValueGetValue(axRange, .cfRange, &cfRange), cfRange.length > 0 {
                    var boundsValue: AnyObject?
                    let boundsError = AXUIElementCopyParameterizedAttributeValue(
                        element,
                        kAXBoundsForRangeParameterizedAttribute as CFString,
                        axRange,
                        &boundsValue
                    )

                    if boundsError == .success,
                       let boundsRef = boundsValue,
                       let cocoaRect = Self.cocoaScreenRect(fromAXBoundsValue: boundsRef) {
                        return cocoaRect
                    }
                }
            }

            // Fallback to WebKit/Chromium AXSelectedTextMarkerRange bounds if available
            var markerRangeRef: AnyObject?
            let markerRangeError = AXUIElementCopyAttributeValue(
                element,
                "AXSelectedTextMarkerRange" as CFString,
                &markerRangeRef
            )
            if markerRangeError == .success, let markerRange = markerRangeRef {
                var boundsValue: AnyObject?
                let boundsError = AXUIElementCopyParameterizedAttributeValue(
                    element,
                    "AXBoundsForTextMarkerRange" as CFString,
                    markerRange,
                    &boundsValue
                )
                if boundsError == .success,
                   let boundsRef = boundsValue,
                   let cocoaRect = Self.cocoaScreenRect(fromAXBoundsValue: boundsRef) {
                    return cocoaRect
                }
            }
        }

        return CGRect(origin: NSEvent.mouseLocation, size: .zero)
    }

    private static func cocoaScreenRect(fromAXBoundsValue boundsRef: AnyObject) -> CGRect? {
        guard CFGetTypeID(boundsRef) == AXValueGetTypeID() else {
            return nil
        }
        let axBounds = boundsRef as! AXValue
        var cgRect = CGRect.zero
        guard AXValueGetValue(axBounds, .cgRect, &cgRect),
              !cgRect.isNull,
              !cgRect.isInfinite,
              (cgRect.width > 0 || cgRect.height > 0),
              cgRect.origin != .zero else {
            return nil
        }
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
