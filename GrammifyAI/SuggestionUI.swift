import SwiftUI
import SwiftData
import AppKit

struct SuggestionUI: View {
    @StateObject var appState: AppState
    @Environment(\.controlActiveState) var controlActiveState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var historyStore: HistoryStore?
    @State private var currentTask: Task<Void, Never>?
    var llmClient = LlmClient()

    private var isNearSelectionMode: Bool {
        appState.selectionAnchorRect != nil
    }

    private var resizeStateHash: Int {
        var hasher = Hasher()
        hasher.combine(appState.windowPositionToken)
        hasher.combine(appState.isOpenAIRequestPending)
        hasher.combine(appState.isOpenAIError)
        hasher.combine(appState.isAccessibilityAPIError)
        hasher.combine(appState.originalText)
        hasher.combine(appState.suggestion)
        hasher.combine(appState.detectedErrors.count)
        for error in appState.detectedErrors {
            hasher.combine(error.category.rawValue)
            hasher.combine(error.originalFragment)
            hasher.combine(error.correctedFragment)
        }
        hasher.combine(appState.openAIError)
        hasher.combine(appState.errorDetails)
        hasher.combine(appState.accessibilityAPIError)
        return hasher.finalize()
    }

    private struct ErrorBadgeItem: Identifiable {
        let category: ErrorCategory
        let tooltips: [String]
        var id: String { category.rawValue }
    }

    private var groupedErrorBadges: [ErrorBadgeItem] {
        var seen: [ErrorCategory: Int] = [:]
        var items: [ErrorBadgeItem] = []

        for error in appState.detectedErrors {
            let orig = error.originalFragment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let corr = error.correctedFragment?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let tooltip: String? = (!orig.isEmpty || !corr.isEmpty) ? "\"\(orig)\" → \"\(corr)\"" : nil

            if let idx = seen[error.category] {
                if let tooltip = tooltip, !items[idx].tooltips.contains(tooltip) {
                    items[idx] = ErrorBadgeItem(
                        category: error.category,
                        tooltips: items[idx].tooltips + [tooltip]
                    )
                }
            } else {
                seen[error.category] = items.count
                items.append(ErrorBadgeItem(
                    category: error.category,
                    tooltips: tooltip.map { [$0] } ?? []
                ))
            }
        }

        return items
    }

    @ViewBuilder
    private var errorCategoriesView: some View {
        if appState.detectedErrors.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Perfect — no errors found")
            }
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.green.opacity(0.15))
            .foregroundStyle(.green)
            .clipShape(Capsule())
        } else {
            FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(groupedErrorBadges) { item in
                    Text("\(item.category.rawValue) · \(item.category.description)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                        .help(item.tooltips.joined(separator: "\n"))
                }
            }
        }
    }

    @ViewBuilder
    private var suggestionContent: some View {
        if (appState.isAccessibilityAPIError) {
            VStack(alignment: .leading, spacing: 10) {
                Text(appState.accessibilityAPIError)
                    .foregroundStyle(.red)

                if !appState.accessibilityAPIPermissionSetUp {
                    HStack(spacing: 8) {
                        Button("Grant Accessibility Permission") {
                            appState.requestAccessibilityPermission()
                        }
                        Button("Open System Settings") {
                            appState.openAccessibilitySettings()
                        }
                    }
                }
            }
        } else if (appState.isOpenAIError) {
            VStack(alignment: .leading, spacing: 8) {
                Text(appState.openAIError)
                    .foregroundColor(.red)
                    .font(.headline)
                if !appState.errorDetails.isEmpty {
                    Text("Server Response:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ScrollView {
                        Text(appState.errorDetails)
                            .foregroundColor(.gray)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                }
            }
        } else if (appState.isOpenAIRequestPending) {
            Text("API request...").foregroundStyle(.blue)
        } else {
            Text(appState.originalText).foregroundStyle(.yellow)
            Divider()

            Text(DiffChecker.diffCheck(incorrectString: appState.originalText, correctString: appState.suggestion))
            errorCategoriesView
            Divider()

            Text("Suggestion is copied to the clipboard")
                .italic()
                .foregroundColor(.gray)
        }
    }

    var body: some View {
        Group {
            if isNearSelectionMode {
                AutoSizingVStackLayout(minWidth: 240, maxWidth: 520, spacing: 8) {
                    suggestionContent
                }
                .padding()
                .fixedSize(horizontal: true, vertical: true)
            } else {
                VStack(alignment: .leading) {
                    suggestionContent
                }
                .padding()
                .frame(minWidth: 600, minHeight: 300)
            }
        }
        .background(
            SuggestionWindowPositioner(
                anchorRect: appState.selectionAnchorRect,
                positionToken: appState.windowPositionToken,
                resizeStateHash: resizeStateHash
            )
        )
        .onChange(of: controlActiveState) { oldState, newState in
            if newState == .inactive {
                appState.showSuggestionUI = false
                dismiss()
            }
        }
        .onChange(of: appState.requestID, initial: true) { oldState, newState in
            if appState.preventAPIInteraction || appState.isAccessibilityAPIError {
                return
            }

            let textToCheck = appState.originalText
            guard !textToCheck.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }

            guard appState.lastProcessedRequestID != newState else {
                return
            }
            appState.lastProcessedRequestID = newState

            currentTask?.cancel()
            appState.cleanOpenAIRequestState()

            currentTask = Task {
                appState.isOpenAIRequestPending = true
                let result = await llmClient.correctWritting(text: textToCheck)
                guard !Task.isCancelled else { return }
                appState.isOpenAIRequestPending = false

                if result.isSuccessful() {
                    appState.suggestion = result.output
                    appState.detectedErrors = result.errors
                    appState.detectedLanguage = result.detectedLanguage
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.suggestion, forType: .string)

                    // Save to history with detected language
                    saveToHistory(
                        originalText: textToCheck,
                        correctedText: result.output,
                        errors: result.errors,
                        language: result.detectedLanguage.isEmpty ? "unknown" : result.detectedLanguage
                    )
                } else {
                    appState.isOpenAIError = true
                    appState.openAIError = result.error
                    appState.errorDetails = result.errorDetails
                }
            }
        }
    }

    @MainActor
    private func saveToHistory(
        originalText: String,
        correctedText: String,
        errors: [CorrectionError],
        language: String
    ) {
        // Initialize store if needed
        if historyStore == nil {
            historyStore = HistoryStore(modelContainer: modelContext.container)
        }

        // Save the record
        historyStore?.createRecord(
            originalText: originalText,
            correctedText: correctedText,
            errors: errors,
            language: language
        )
        appState.historyVersion += 1
    }
}

private struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let maxWidth = proposal.width ?? .infinity

        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0 && currentX + size.width > maxWidth {
                maxRowWidth = max(maxRowWidth, currentX - horizontalSpacing)
                totalHeight += currentRowHeight + verticalSpacing
                currentX = 0
                currentRowHeight = 0
            }
            currentX += size.width + horizontalSpacing
            currentRowHeight = max(currentRowHeight, size.height)
        }

        if currentX > 0 {
            maxRowWidth = max(maxRowWidth, currentX - horizontalSpacing)
            totalHeight += currentRowHeight
        }

        return CGSize(width: maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let maxWidth = bounds.width > 0 ? bounds.width : (proposal.width ?? .infinity)

        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > bounds.minX && (currentX - bounds.minX) + size.width > maxWidth {
                currentX = bounds.minX
                currentY += currentRowHeight + verticalSpacing
                currentRowHeight = 0
            }
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            currentX += size.width + horizontalSpacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

private struct AutoSizingVStackLayout: Layout {
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let spacing: CGFloat

    private func resolvedWidth(for subviews: Subviews) -> CGFloat {
        var widest: CGFloat = minWidth
        for subview in subviews {
            let ideal = subview.sizeThatFits(.unspecified)
            // Ignore Divider's tiny ideal width or unbounded widths; clamp to maxWidth
            if ideal.width > widest {
                widest = min(ideal.width, maxWidth)
            }
        }
        return min(max(widest, minWidth), maxWidth)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = resolvedWidth(for: subviews)
        let childProposal = ProposedViewSize(width: width, height: nil)

        var totalHeight: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(childProposal)
            totalHeight += size.height
            if index < subviews.count - 1 {
                totalHeight += spacing
            }
        }

        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        let childProposal = ProposedViewSize(width: width, height: nil)
        var currentY = bounds.minY

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(childProposal)
            subview.place(
                at: CGPoint(x: bounds.minX, y: currentY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: size.height)
            )
            currentY += size.height
            if index < subviews.count - 1 {
                currentY += spacing
            }
        }
    }
}

private struct SuggestionWindowPositioner: NSViewRepresentable {
    let anchorRect: CGRect?
    let positionToken: UUID
    let resizeStateHash: Int

    func makeNSView(context: Context) -> PositioningNSView {
        let view = PositioningNSView()
        view.anchorRect = anchorRect
        view.positionToken = positionToken
        view.resizeStateHash = resizeStateHash
        return view
    }

    func updateNSView(_ nsView: PositioningNSView, context: Context) {
        nsView.anchorRect = anchorRect
        nsView.positionToken = positionToken
        nsView.resizeStateHash = resizeStateHash
        nsView.applyPositionIfNeeded()
    }

    final class PositioningNSView: NSView {
        var anchorRect: CGRect?
        var positionToken: UUID = UUID()
        var resizeStateHash: Int = 0
        private var lastAppliedToken: UUID?
        private var lastAppliedResizeHash: Int?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            lastAppliedToken = nil
            lastAppliedResizeHash = nil
            applyPositionIfNeeded()
        }

        func applyPositionIfNeeded() {
            guard let window = self.window else { return }

            let tokenChanged = (lastAppliedToken != positionToken)
            let resizeChanged = (lastAppliedResizeHash != resizeStateHash)

            guard tokenChanged || (anchorRect != nil && resizeChanged) else {
                return
            }

            lastAppliedToken = positionToken
            lastAppliedResizeHash = resizeStateHash
            let rect = anchorRect

            Self.position(window: window, near: rect, centerIfNil: tokenChanged)
            DispatchQueue.main.async { [weak window] in
                guard let window = window else { return }
                Self.position(window: window, near: rect, centerIfNil: tokenChanged)
            }
        }

        private static func position(window: NSWindow, near anchorRect: CGRect?, centerIfNil: Bool) {
            guard let anchorRect = anchorRect else {
                if window.frame.width < 600 || window.frame.height < 300 {
                    window.setContentSize(NSSize(width: 600, height: 300))
                }
                if centerIfNil {
                    window.center()
                }
                return
            }

            let anchorPoint = CGPoint(x: anchorRect.midX, y: anchorRect.midY)
            let screen = NSScreen.screens.first(where: { NSMouseInRect(anchorPoint, $0.frame, false) })
                ?? NSScreen.main
                ?? NSScreen.screens.first

            guard let visibleFrame = screen?.visibleFrame else {
                window.center()
                return
            }

            if let contentView = window.contentView {
                contentView.layoutSubtreeIfNeeded()
                let fitting = contentView.fittingSize
                if fitting.width > 0 && fitting.height > 0 {
                    let targetContentSize = NSSize(
                        width: min(max(fitting.width, 260), visibleFrame.width - 32),
                        height: min(max(fitting.height, 48), visibleFrame.height - 64)
                    )
                    window.setContentSize(targetContentSize)
                }
            }

            let windowSize = window.frame.size
            let spacing: CGFloat = 8

            let minX = visibleFrame.minX
            let maxX = max(minX, visibleFrame.maxX - windowSize.width)
            let targetX = min(max(anchorRect.minX, minX), maxX)

            let minY = visibleFrame.minY
            let maxY = max(minY, visibleFrame.maxY - windowSize.height)
            let belowY = anchorRect.minY - windowSize.height - spacing
            let aboveY = anchorRect.maxY + spacing
            let rawY = (belowY >= minY) ? belowY : aboveY
            let targetY = min(max(rawY, minY), maxY)

            window.setFrameOrigin(NSPoint(x: targetX, y: targetY))
        }
    }
}

#Preview {
    let appState = AppState()
    appState.originalText = "I a supor original text"
    appState.suggestion = "I am corrected text"
    appState.detectedErrors = [
        CorrectionError(category: .SYN, originalFragment: "I a", correctedFragment: "I am"),
        CorrectionError(category: .ORT, originalFragment: "supor", correctedFragment: "super")
    ]
    appState.isOpenAIRequestPending = false
    appState.preventAPIInteraction = true

    return SuggestionUI(appState: appState)
        .frame(width: 600, height: 300)
}

