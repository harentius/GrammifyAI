# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

GrammifyAI is a minimalist macOS menu bar application that provides LLM-powered grammar checking and writing improvement for any application. It uses the macOS Accessibility API to read selected text system-wide and displays corrections in a diff view.

**Key Features:**
- Global keyboard shortcut (`⌘ + U` by default) to check selected text
- Works with any web or native macOS application (except Google Docs)
- OpenAI-compatible API integration (configurable endpoint and model)
- Diff-based correction display with color-coded changes
- Automatic clipboard copying of corrected text

## Build and Run

**Build the app:**
```bash
xcodebuild -scheme GrammifyAI -configuration Release build
```

**Run in Xcode:**
Open `GrammifyAI.xcodeproj` in Xcode and press `⌘ + R`

**Build for distribution:**
```bash
xcodebuild -scheme GrammifyAI -configuration Release archive -archivePath ./build/GrammifyAI.xcarchive
```

**Note:** The app requires Accessibility permissions to function. During development, Xcode may need to be added to Accessibility settings.

## Architecture

### Core Components

**GrammifyAIApp.swift** - Main entry point
- Sets up MenuBarExtra with wand icon
- Manages suggestion window lifecycle
- Observes keyboard shortcut via `SelectionManager`

**AppState.swift** - Central state management
- Observable object shared across UI components
- Handles precondition checks (Accessibility API, OpenAI key)
- Manages keyboard shortcut callback via KeyboardShortcuts library
- Coordinates UI state (settings, suggestions, errors)

**SelectionManager.swift** - Text selection via Accessibility API
- Uses `AXUIElementCreateSystemWide()` to access focused UI elements
- Reads `kAXSelectedTextAttribute` from focused element
- Returns `Result` type with success/error state

**LlmClient.swift** (`OpenAIHelper.swift`) - LLM API integration
- Sends text to OpenAI-compatible endpoint using structured `system` and `user` messages with `response_format: json_object` and `temperature: 0.1`
- Supports custom API URLs via settings (defaults to OpenAI)
- Returns `Result` with corrected text, detected language, classified error fragments, or error details

**SuggestionUI.swift** - Correction display window
- Shows original text, word-level diff view, detected error category badges (with fragment tooltips), and error states
- Triggers LLM request on `originalText` change
- Automatically copies suggestion to clipboard
- Closes when window loses focus

**DiffChecker.swift** - Text diff visualization
- Tokenizes text into words and uses SwiftDiff library to compute word-level diffs between original and corrected text
- Returns `AttributedString` with color-coded changes (green=insert, red=delete)

**SettingsManager.swift** - User preferences persistence
- Stores API token in macOS Keychain (with automatic migration from legacy `UserDefaults`), and URL, model, and launch-at-login via `UserDefaults`
- Defaults: `https://api.openai.com` and `gpt-4o-mini`
- Handles `SMAppService` registration for launch-at-login (macOS 13+)

### Data Flow

1. User presses keyboard shortcut → `AppState` keyboard callback fires
2. `SelectionManager.getSelectedText()` retrieves selected text via Accessibility API
3. `AppState.originalText` is set → `SuggestionUI` displays and triggers LLM request
4. `LlmClient.correctWritting()` sends text to API
5. Response is stored in `AppState.suggestion` and copied to clipboard
6. `DiffChecker` renders visual diff in UI

### Dependencies

- **KeyboardShortcuts** (sindresorhus/KeyboardShortcuts @ 2.0.1) - Global keyboard shortcut management
- **SwiftDiff** (kvasnikoff/SwiftDiff5 @ master) - Text diff algorithm

## Important Implementation Details

**Accessibility API:** The app requires `AXIsProcessTrusted()` to return true. When permission is not granted on launch, `AppState.requestAccessibilityPermission()` resets any stale TCC entry via `tccutil reset Accessibility` and calls `AXIsProcessTrustedWithOptions` with `kAXTrustedCheckOptionPrompt: true` to show the native macOS prompt, polling until permission is granted. When operations fail, descriptive error codes are returned (see `AXError.swift` for error code mapping).

**API Token Storage:** The OpenAI API token is stored securely in the macOS Keychain (`kSecClassGenericPassword`) and cached in memory for the session, with automatic migration from legacy `UserDefaults` storage.

**Statistics Storage:** Correction history and statistics are stored via SwiftData in an app-specific file at `~/Library/Application Support/harentius.GrammifyAI/GrammifyAI.store` (with one-time migration from the legacy `~/Library/Application Support/default.store` location).

**Window Management:** The suggestion window uses `MenuBarExtra` with `.window` style and is shown/hidden via `openWindow(id: "suggestion")` and `controlActiveState` observation. When "Open suggestion near selected text" is enabled in settings, the window is positioned next to the selection bounds (or mouse cursor fallback) and automatically resized to fit its content.

**Keyboard Shortcut:** The shortcut is defined via the KeyboardShortcuts library with name `.improveWriting`. Default is `⌘ + U` but users can customize in settings.

**LLM Integration:** The client supports any OpenAI-compatible API by parsing the URL into components (scheme, host, port, basePath) and appending `/chat/completions`. Error responses include full server response body for debugging.
