# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

**LlmClient.swift** - LLM API integration
- Sends text to OpenAI-compatible endpoint
- Constructs prompt: "Correct the writing of provided text. Response only with updated version, without any additional explanations."
- Supports custom API URLs via settings (defaults to OpenAI)
- Returns `Result` with corrected text or error details

**SuggestionUI.swift** - Correction display window
- Shows original text, diff view, and error states
- Triggers LLM request on `originalText` change
- Automatically copies suggestion to clipboard
- Closes when window loses focus

**DiffChecker.swift** - Text diff visualization
- Uses SwiftDiff library to compare original and corrected text
- Returns `AttributedString` with color-coded changes (green=insert, red=delete)

**SettingsManager.swift** - User preferences persistence
- Stores API token, URL, model, and launch-at-login via `UserDefaults`
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

**Accessibility API:** The app requires `AXIsProcessTrusted()` to return true. When permission is not granted, operations fail with descriptive error codes (see `AXError.swift` for error code mapping).

**API Token Storage:** The OpenAI API token is stored in `UserDefaults` **unencrypted**. This is documented in the README as a security consideration.

**Window Management:** The suggestion window uses `MenuBarExtra` with `.window` style and is shown/hidden via `openWindow(id: "suggestion")` and `controlActiveState` observation.

**Keyboard Shortcut:** The shortcut is defined via the KeyboardShortcuts library with name `.improveWriting`. Default is `⌘ + U` but users can customize in settings.

**LLM Integration:** The client supports any OpenAI-compatible API by parsing the URL into components (scheme, host, port, basePath) and appending `/chat/completions`. Error responses include full server response body for debugging.
