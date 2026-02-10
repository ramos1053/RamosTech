import SwiftUI
import AppKit
import Combine

/// Main editor view using NSTextView with ruler and line numbers support
struct EditorView: NSViewRepresentable {
    @ObservedObject var textEngine: TextEngine
    @ObservedObject var preferences = AppPreferences.shared
    let documentInfo: DocumentManager.DocumentInfo?

    init(textEngine: TextEngine, documentInfo: DocumentManager.DocumentInfo? = nil) {
        self.textEngine = textEngine
        self.documentInfo = documentInfo
    }

    func makeNSView(context: Context) -> NSScrollView {
        // Create custom layout manager for colored invisible characters
        let layoutManager = ColoredInvisiblesLayoutManager()
        let textStorage = NSTextStorage()
        let textContainer = NSTextContainer()

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        // Create custom text view with custom layout manager
        let textView = CustomTextView(frame: .zero, textContainer: textContainer)

        // Create scroll view
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        // Ensure documentView is set before continuing
        guard let textView = scrollView.documentView as? CustomTextView else {
            return scrollView
        }

        // Store coordinator reference
        context.coordinator.scrollView = scrollView
        context.coordinator.textView = textView
        context.coordinator.documentInfo = documentInfo

        // Configure text view for BBEdit-like behavior
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false

        let theme = preferences.currentTheme
        textView.font = preferences.editorFont
        textView.textColor = theme.textColor.nsColor
        textView.backgroundColor = theme.backgroundColor.nsColor
        textView.actualCursorColor = theme.cursorColor.nsColor

        // Keep system cursor hidden
        textView.insertionPointColor = .clear

        // Apply cursor settings
        textView.updateCursorSettings(type: preferences.cursorType, blinks: preferences.cursorBlinks)

        // Apply current line highlighting
        textView.showCurrentLineHighlight = preferences.showCurrentLineHighlight
        textView.currentLineHighlightColor = highlightColorFromString(preferences.currentLineHighlightColor)

        // Set document URL for completion provider file type detection
        textView.documentURL = documentInfo?.url

        // Disable automatic substitutions (BBEdit behavior)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = preferences.enableAutoCompletion
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false

        // Enable smart insert/delete for proper spacing (standard macOS)
        textView.smartInsertDeleteEnabled = true

        // Use standard character deletion
        textView.usesFontPanel = true
        textView.usesFindPanel = true

        // Enable undo/redo
        textView.allowsUndo = true

        // Configure undo manager levels limit
        textView.undoManager?.levelsOfUndo = preferences.undoHistoryLimit

        // Configure container
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !preferences.wrapLines
        textView.autoresizingMask = preferences.wrapLines ? [.width] : []

        if preferences.wrapLines {
            textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = true
        } else {
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = false
        }

        // Set minSize to prevent unnecessary scrollbar
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // Ensure text view frame starts at origin (0,0) to prevent horizontal shift
        textView.frame.origin = CGPoint(x: 0, y: 0)

        // Configure scroll view
        scrollView.hasVerticalRuler = preferences.showLineNumbers
        scrollView.hasHorizontalRuler = false // Custom ruler handled in ContentView
        scrollView.rulersVisible = preferences.showLineNumbers

        // Add line number ruler
        if preferences.showLineNumbers {
            let lineNumberRuler = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
            lineNumberRuler.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            lineNumberRuler.textColor = theme.lineNumberColor.nsColor
            lineNumberRuler.backgroundColor = theme.lineNumberBackgroundColor.nsColor
            lineNumberRuler.showSeparator = preferences.showLineNumberSeparator
            scrollView.verticalRulerView = lineNumberRuler
        }

        // Set initial text
        textView.string = textEngine.text

        // Set cursor to beginning and ensure view is scrolled to top-left
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        // Force scroll to top-left corner immediately
        scrollView.contentView.setBoundsOrigin(.zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)

        // Also scroll the document view to ensure proper positioning
        scrollView.documentView?.scroll(NSPoint.zero)

        // Make text view first responder immediately to enable editing
        if let window = scrollView.window {
            _ = window.makeFirstResponder(textView)
        }

        // Ensure scroll position persists after layout by doing it again slightly delayed
        DispatchQueue.main.async {
            scrollView.contentView.setBoundsOrigin(.zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            textView.setSelectedRange(NSRange(location: 0, length: 0))

            // Force visible rect to start at origin
            textView.scrollToVisible(NSRect(x: 0, y: 0, width: 1, height: 1))
        }

        // Also do it after a longer delay to catch any late layout changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            scrollView.contentView.setBoundsOrigin(.zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scrollToVisible(NSRect(x: 0, y: 0, width: 1, height: 1))
        }

        // Apply initial syntax highlighting
        // Runs in background thread, won't block UI
        if preferences.enableSyntaxColoring {
            context.coordinator.applySyntaxHighlighting(to: textView)
        }

        // Observe preference changes for syntax coloring
        let syntaxObserver = preferences.$enableSyntaxColoring.sink { enabled in
            DispatchQueue.main.async {
                if enabled {
                    context.coordinator.applySyntaxHighlighting(to: textView)
                } else {
                    context.coordinator.removeSyntaxHighlighting(from: textView)
                }
            }
        }
        context.coordinator.syntaxColoringObserver = syntaxObserver

        // Observe theme changes to re-apply syntax highlighting with new theme colors
        let themeObserver = preferences.$selectedThemeID.sink { _ in
            DispatchQueue.main.async {
                if preferences.enableSyntaxColoring {
                    context.coordinator.applySyntaxHighlighting(to: textView)
                }
            }
        }
        context.coordinator.themeObserver = themeObserver

        // Also trigger when window becomes key
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { notification in
            if let window = notification.object as? NSWindow {
                _ = window.makeFirstResponder(textView)
                textView.setNeedsDisplay(textView.visibleRect)
            }
        }

        // Listen for scroll to left notification (for header insertion)
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ScrollToLeft"), object: nil, queue: .main) { _ in
            // Scroll both the clip view and the text view to left edge
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollView.contentView.bounds.origin.y))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            // Also force textView to scroll to show the origin
            textView.scrollToVisible(NSRect(x: 0, y: scrollView.contentView.bounds.origin.y, width: 1, height: 1))
        }

        // Listen for find/replace notifications
        NotificationCenter.default.addObserver(forName: .findNext, object: nil, queue: .main) { notification in
            guard let request = notification.object as? FindRequest else { return }
            Task { @MainActor in
                context.coordinator.performFind(textView: textView, request: request, forward: true)
            }
        }

        NotificationCenter.default.addObserver(forName: .findPrevious, object: nil, queue: .main) { notification in
            guard let request = notification.object as? FindRequest else { return }
            Task { @MainActor in
                context.coordinator.performFind(textView: textView, request: request, forward: false)
            }
        }

        NotificationCenter.default.addObserver(forName: .replaceNext, object: nil, queue: .main) { notification in
            guard let request = notification.object as? ReplaceRequest else { return }
            Task { @MainActor in
                context.coordinator.performReplace(textView: textView, request: request, replaceAll: false)
            }
        }

        NotificationCenter.default.addObserver(forName: .replaceAll, object: nil, queue: .main) { notification in
            guard let request = notification.object as? ReplaceRequest else { return }
            Task { @MainActor in
                context.coordinator.performReplace(textView: textView, request: request, replaceAll: true)
            }
        }

        NotificationCenter.default.addObserver(forName: .clearSearchHighlights, object: nil, queue: .main) { _ in
            Task { @MainActor in
                context.coordinator.clearSearchHighlights(textView: textView)
            }
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CustomTextView else {
            return
        }

        let theme = preferences.currentTheme

        // Sync text from TextEngine to NSTextView (for undo/redo operations)
        if textView.string != textEngine.text {
            let savedSelection = textView.selectedRange()
            textView.string = textEngine.text
            // Restore cursor position if valid
            if savedSelection.location <= textEngine.text.count {
                textView.setSelectedRange(savedSelection)
            }
        }

        // Update font
        if textView.font != preferences.editorFont {
            textView.font = preferences.editorFont
        }

        // Update theme colors
        // NOTE: Don't set textView.textColor when syntax coloring is enabled
        // as it overrides individual character colors set by syntax highlighting
        // textView.textColor = theme.textColor.nsColor
        textView.backgroundColor = theme.backgroundColor.nsColor
        textView.actualCursorColor = theme.cursorColor.nsColor

        // Always keep system cursor hidden
        textView.insertionPointColor = .clear

        // Apply cursor settings
        textView.updateCursorSettings(type: preferences.cursorType, blinks: preferences.cursorBlinks)

        // Apply current line highlighting
        textView.showCurrentLineHighlight = preferences.showCurrentLineHighlight
        textView.currentLineHighlightColor = highlightColorFromString(preferences.currentLineHighlightColor)

        // Update line wrapping
        if preferences.wrapLines {
            textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = true
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
        } else {
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = false
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = []
        }

        // Update auto-completion
        textView.isAutomaticTextCompletionEnabled = preferences.enableAutoCompletion

        // Update undo levels
        textView.undoManager?.levelsOfUndo = preferences.undoHistoryLimit

        // Update ruler visibility
        scrollView.hasVerticalRuler = preferences.showLineNumbers
        scrollView.hasHorizontalRuler = false // Custom ruler handled in ContentView
        scrollView.rulersVisible = preferences.showLineNumbers

        // Add/remove line number ruler
        if preferences.showLineNumbers {
            if let lineNumberRuler = scrollView.verticalRulerView as? LineNumberRulerView {
                // Update existing ruler colors and settings
                lineNumberRuler.textColor = theme.lineNumberColor.nsColor
                lineNumberRuler.backgroundColor = theme.lineNumberBackgroundColor.nsColor
                lineNumberRuler.showSeparator = preferences.showLineNumberSeparator
            } else {
                // Create new ruler
                let lineNumberRuler = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
                lineNumberRuler.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
                lineNumberRuler.textColor = theme.lineNumberColor.nsColor
                lineNumberRuler.backgroundColor = theme.lineNumberBackgroundColor.nsColor
                lineNumberRuler.showSeparator = preferences.showLineNumberSeparator
                scrollView.verticalRulerView = lineNumberRuler
            }
        } else {
            scrollView.verticalRulerView = nil
        }

        // Update text if it changed externally
        // IMPORTANT: Only update when text actually differs to preserve syntax highlighting
        if textView.string != textEngine.text {
            _ = textView.selectedRange()

            // Use textStorage to preserve formatting when possible
            if let textStorage = textView.textStorage {
                textStorage.beginEditing()
                textStorage.replaceCharacters(in: NSRange(location: 0, length: textStorage.length), with: textEngine.text)
                textStorage.endEditing()
            } else {
                textView.string = textEngine.text
            }

            // Restore cursor position
            let newPosition = min(textEngine.cursorPosition, textView.string.count)
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))
        } else {
            // Text hasn't changed, but cursor position might have - sync it
            let currentCursorPos = textView.selectedRange().location
            if currentCursorPos != textEngine.cursorPosition {
                let newPosition = min(textEngine.cursorPosition, textView.string.count)
                textView.setSelectedRange(NSRange(location: newPosition, length: 0))
            }
        }

        // Update invisible characters
        if let layoutManager = textView.layoutManager as? ColoredInvisiblesLayoutManager {
            layoutManager.showsInvisibleCharacters = preferences.showInvisibles

            // Set color for invisible characters based on preference
            let invisiblesColor: NSColor
            switch preferences.invisibleCharactersColor {
            case "gray":
                invisiblesColor = NSColor.systemGray
            case "blue":
                invisiblesColor = NSColor.systemBlue
            case "red":
                invisiblesColor = NSColor.systemRed
            case "green":
                invisiblesColor = NSColor.systemGreen
            case "orange":
                invisiblesColor = NSColor.systemOrange
            default:
                invisiblesColor = NSColor.systemGray
            }
            layoutManager.invisibleCharactersColor = invisiblesColor

            // Set individual invisible character types
            layoutManager.showLineEndingsInvisible = preferences.showLineEndingsInvisible
            layoutManager.showTabInvisible = preferences.showTabInvisible
            layoutManager.showSpaceInvisible = preferences.showSpaceInvisible
            layoutManager.showWhitespaceInvisible = preferences.showWhitespaceInvisible
            layoutManager.showControlCharactersInvisible = preferences.showControlCharactersInvisible
        }

        // Note: Syntax highlighting is now handled in textDidChange with debouncing
        // Removed from here to prevent excessive re-highlighting on every view update
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(textEngine: textEngine, documentInfo: documentInfo)
    }

    // Helper function to convert color string to NSColor
    private func highlightColorFromString(_ colorString: String) -> NSColor {
        switch colorString {
        case "lightgray":
            return NSColor.lightGray.withAlphaComponent(0.15)
        case "lightblue":
            return NSColor.systemBlue.withAlphaComponent(0.1)
        case "lightyellow":
            return NSColor.systemYellow.withAlphaComponent(0.15)
        case "lightgreen":
            return NSColor.systemGreen.withAlphaComponent(0.1)
        case "lightpink":
            return NSColor.systemPink.withAlphaComponent(0.1)
        default:
            return NSColor.lightGray.withAlphaComponent(0.15)
        }
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate, @unchecked Sendable {
        let textEngine: TextEngine
        var documentInfo: DocumentManager.DocumentInfo?
        weak var scrollView: NSScrollView?
        weak var textView: CustomTextView?
        private var currentLanguage: SyntaxHighlighter.Language = .plainText

        // Store search results for reapplying highlights after syntax highlighting
        private var currentSearchResults: [SearchResult] = []
        private var currentMatchIndex: Int = 0

        // Debounce timer for syntax highlighting
        private var syntaxHighlightingTimer: Timer?

        // Observer for syntax coloring preference changes
        var syntaxColoringObserver: AnyCancellable?

        // Observer for theme changes
        var themeObserver: AnyCancellable?

        init(textEngine: TextEngine, documentInfo: DocumentManager.DocumentInfo?) {
            self.textEngine = textEngine
            self.documentInfo = documentInfo

            // Detect language from file extension
            if let url = documentInfo?.url {
                let fileExtension = url.pathExtension
                self.currentLanguage = SyntaxHighlighter.Language.detect(from: fileExtension)
            }

            super.init()
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
            syntaxHighlightingTimer?.invalidate()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            // Sync text back to engine immediately
            let newText = textView.string
            if newText != textEngine.text {
                textEngine.syncTextFromView(newText)
                textEngine.cursorPosition = textView.selectedRange().location
            }

            // Update line numbers immediately
            scrollView?.verticalRulerView?.needsDisplay = true

            // Debounced syntax highlighting - only if preference is enabled
            if AppPreferences.shared.enableSyntaxColoring {
                // Invalidate any existing timer
                syntaxHighlightingTimer?.invalidate()

                // Schedule new timer with 0.5s delay
                syntaxHighlightingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    Task { @MainActor in
                        self.applySyntaxHighlighting(to: textView)
                    }
                }
            }
        }

        @MainActor
        func applySyntaxHighlighting(to textView: NSTextView) {
            // Capture values needed for background work
            let text = textView.string

            // Skip syntax highlighting for very large files (>100KB) to maintain performance
            if text.utf8.count > 100_000 {
                return
            }

            let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let fontName = font.fontName
            let fontSize = font.pointSize
            let theme = AppPreferences.shared.currentTheme

            // Auto-detect language from shebang if no file extension
            var languageToUse = currentLanguage
            if currentLanguage == .plainText && text.hasPrefix("#!") {
                // Extract shebang and detect language
                if let firstLine = text.components(separatedBy: .newlines).first {
                    let shebang = firstLine.lowercased()
                    if shebang.contains("bash") || shebang.contains("/sh") {
                        languageToUse = .bash
                    } else if shebang.contains("python") {
                        languageToUse = .python
                    } else if shebang.contains("ruby") {
                        languageToUse = .ruby
                    } else if shebang.contains("perl") {
                        languageToUse = .perl
                    } else if shebang.contains("php") {
                        languageToUse = .php
                    } else if shebang.contains("node") {
                        languageToUse = .javascript
                    } else if shebang.contains("zsh") {
                        languageToUse = .shell
                    }
                }
            }

            // Perform heavy computation in background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self, fontName, fontSize] in
                // Recreate font from captured properties (avoids Sendable warning)
                let font = NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

                // Create highlighter
                let highlighter = SyntaxHighlighter()

                // Get attributed string with syntax colors (heavy computation)
                let attributedString = highlighter.attributedString(for: text, baseFont: font, theme: theme, language: languageToUse)

                // Apply result back on main thread
                DispatchQueue.main.async {
                    guard let self = self,
                          let textStorage = textView.textStorage,
                          textView.string == text else {
                        // Text changed while we were processing, skip this update
                        return
                    }

                    // Store selection
                    let savedSelection = textView.selectedRange()

                    // Replace text storage contents
                    textStorage.beginEditing()
                    textStorage.setAttributedString(attributedString)
                    textStorage.endEditing()

                    // Restore selection
                    textView.setSelectedRange(savedSelection)

                    // Reapply search highlights if any exist
                    self.reapplySearchHighlights(to: textView)
                }
            }
        }

        @MainActor
        func reapplySearchHighlights(to textView: NSTextView) {
            guard !currentSearchResults.isEmpty, let textStorage = textView.textStorage else { return }

            // Highlight all matches with orange background
            let orangeHighlight = NSColor.systemOrange.withAlphaComponent(0.5)
            for result in currentSearchResults {
                // Ensure range is still valid
                if result.range.location + result.range.length <= textStorage.length {
                    textStorage.addAttribute(.backgroundColor, value: orangeHighlight, range: result.range)
                }
            }

            // Highlight current match with bright red-orange color
            if currentMatchIndex < currentSearchResults.count {
                let currentResult = currentSearchResults[currentMatchIndex]
                if currentResult.range.location + currentResult.range.length <= textStorage.length {
                    let currentMatchHighlight = NSColor(calibratedRed: 1.0, green: 0.4, blue: 0.0, alpha: 0.7)
                    textStorage.addAttribute(.backgroundColor, value: currentMatchHighlight, range: currentResult.range)
                }
            }
        }

        @MainActor
        func removeSyntaxHighlighting(from textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            let text = textView.string
            let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let theme = AppPreferences.shared.currentTheme

            // Store selection
            let savedSelection = textView.selectedRange()

            // Reset to plain text with theme colors
            textStorage.beginEditing()
            textStorage.setAttributedString(NSAttributedString(string: text))
            textStorage.addAttribute(.font, value: font, range: NSRange(location: 0, length: textStorage.length))
            textStorage.addAttribute(.foregroundColor, value: theme.textColor.nsColor, range: NSRange(location: 0, length: textStorage.length))
            textStorage.endEditing()

            // Restore selection
            textView.setSelectedRange(savedSelection)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            let range = textView.selectedRange()

            // Update cursor position on main thread
            DispatchQueue.main.async { [weak textEngine] in
                textEngine?.cursorPosition = range.location

                if range.length > 0 {
                    textEngine?.selectionRange = range.location..<(range.location + range.length)
                } else {
                    textEngine?.selectionRange = nil
                }
            }

            // Force redraw to update current line highlighting
            if let customTextView = textView as? CustomTextView,
               customTextView.showCurrentLineHighlight {
                textView.setNeedsDisplay(textView.visibleRect)
            }
        }

        // Handle key commands
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard let customTextView = textView as? CustomTextView else { return false }

            // Debug logging
            print("DEBUG: doCommandBy called, selector: \(commandSelector)")
            print("DEBUG: isShowingCompletions: \(customTextView.isShowingCompletions)")

            // If completions are showing, intercept navigation keys
            if customTextView.isShowingCompletions {
                switch commandSelector {
                case #selector(NSResponder.moveDown(_:)):
                    customTextView.completionController?.moveSelection(delta: 1)
                    return true

                case #selector(NSResponder.moveUp(_:)):
                    customTextView.completionController?.moveSelection(delta: -1)
                    return true

                case #selector(NSResponder.insertNewline(_:)):
                    if let item = customTextView.completionController?.selectCurrent() {
                        customTextView.insertCompletion(item)
                    } else {
                        // If no item selected, dismiss the menu
                        customTextView.completionController?.dismiss()
                        customTextView.isShowingCompletions = false
                    }
                    return true

                case #selector(NSResponder.cancelOperation(_:)):  // Escape key
                    customTextView.completionController?.dismiss()
                    customTextView.isShowingCompletions = false
                    return true

                default:
                    // Dismiss on other keys - let them pass through for normal editing
                    customTextView.completionController?.dismiss()
                    customTextView.isShowingCompletions = false
                }
            } else {
                // Manual trigger
                if commandSelector == #selector(NSResponder.complete(_:)) {  // Ctrl+Space
                    customTextView.showCompletionsManually()
                    return true
                }
                if commandSelector == #selector(NSResponder.cancelOperation(_:)) {  // Escape
                    customTextView.showCompletionsManually()
                    return true
                }
            }

            // Return false to let NSTextView handle all other commands with standard macOS behavior
            // This gives us BBEdit-like editing with proper single-character deletion,
            // selection handling, and all standard text navigation
            return false
        }

        // MARK: - Find/Replace

        @MainActor
        func clearSearchHighlights(textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            textStorage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: textStorage.length))
            currentSearchResults = []
            currentMatchIndex = 0
        }

        @MainActor
        func performFind(textView: NSTextView, request: FindRequest, forward: Bool) {
            let searchEngine = SearchEngine()
            let options = SearchEngine.SearchOptions(
                caseSensitive: request.caseSensitive,
                wholeWord: request.wholeWord,
                useRegex: request.useRegex
            )

            do {
                // Get all matches
                let results = try searchEngine.findAll(pattern: request.searchText, in: textView.string, options: options)

                guard !results.isEmpty else {
                    return
                }

                guard let textStorage = textView.textStorage else { return }

                // Clear previous search highlighting by removing backgroundColor from entire text
                textStorage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: textStorage.length))

                // Highlight all matches with orange background
                let orangeHighlight = NSColor.systemOrange.withAlphaComponent(0.5)
                for result in results {
                    textStorage.addAttribute(.backgroundColor, value: orangeHighlight, range: result.range)
                }

                // Determine next match index based on stored position or cursor location
                var matchIndex = 0

                // If we have stored search results and they match current search, use stored index
                if currentSearchResults.count == results.count && !currentSearchResults.isEmpty {
                    // Navigate from stored position
                    if forward {
                        matchIndex = (currentMatchIndex + 1) % results.count
                    } else {
                        matchIndex = (currentMatchIndex - 1 + results.count) % results.count
                    }
                } else {
                    // New search - find first/last match relative to cursor
                    let currentLocation = textView.selectedRange().location

                    if forward {
                        // Find first match at or after current position
                        if let foundIndex = results.firstIndex(where: { $0.range.location >= currentLocation }) {
                            matchIndex = foundIndex
                        } else {
                            // Wrap to first
                            matchIndex = 0
                        }
                    } else {
                        // Find last match before current position
                        if let foundIndex = results.lastIndex(where: { $0.range.location < currentLocation }) {
                            matchIndex = foundIndex
                        } else {
                            // Wrap to last
                            matchIndex = results.count - 1
                        }
                    }
                }

                let result = results[matchIndex]

                // Store search results for reapplying after syntax highlighting
                currentSearchResults = results
                currentMatchIndex = matchIndex

                // Highlight current match with bright red-orange color
                let currentMatchHighlight = NSColor(calibratedRed: 1.0, green: 0.4, blue: 0.0, alpha: 0.7)
                textStorage.addAttribute(.backgroundColor, value: currentMatchHighlight, range: result.range)

                // Select the match
                textView.setSelectedRange(result.range)
                textView.scrollRangeToVisible(result.range)
                textView.showFindIndicator(for: result.range)

                // Post notification with match info for UI update
                NotificationCenter.default.post(
                    name: .updateFindMatchInfo,
                    object: FindMatchInfo(currentMatch: matchIndex + 1, totalMatches: results.count)
                )
            } catch {
                // Silent failure - no error beep
            }
        }

        @MainActor
        func performReplace(textView: NSTextView, request: ReplaceRequest, replaceAll: Bool) {
            let searchEngine = SearchEngine()
            let options = SearchEngine.SearchOptions(
                caseSensitive: request.caseSensitive,
                wholeWord: request.wholeWord,
                useRegex: request.useRegex
            )

            do {
                if replaceAll {
                    // Count matches before replacing
                    let matchCount = try searchEngine.count(pattern: request.searchText, in: textView.string, options: options)

                    // Replace all occurrences
                    let newText = try searchEngine.replace(
                        pattern: request.searchText,
                        replacement: request.replaceText,
                        in: textView.string,
                        options: options
                    )

                    // Ensure text view is first responder for proper undo tracking
                    textView.window?.makeFirstResponder(textView)

                    // Update text view using replaceCharacters to preserve undo
                    let fullRange = NSRange(location: 0, length: textView.string.count)
                    if textView.shouldChangeText(in: fullRange, replacementString: newText) {
                        textView.replaceCharacters(in: fullRange, with: newText)
                        textView.didChangeText()
                    }

                    // Note: syncTextFromView is automatically called by textDidChange delegate
                    // Don't call it here as it interferes with undo

                    // Clear stored search results as they're now invalid
                    currentSearchResults = []
                    currentMatchIndex = 0

                    // Clear highlights since there are no more matches
                    guard let textStorage = textView.textStorage else { return }
                    textStorage.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: textStorage.length))

                    // Note: Syntax highlighting will be handled by the debounced timer in textDidChange
                    // Don't apply it here to keep replace operation instant

                    // Show notification with replacement count
                    NotificationCenter.default.post(
                        name: .showReplaceNotification,
                        object: ReplaceNotificationInfo(count: matchCount, isReplaceAll: true)
                    )
                } else {
                    // Replace current selection if it matches
                    let selection = textView.selectedRange()

                    // Check if current selection matches the pattern
                    if selection.length > 0 {
                        let selectedText = (textView.string as NSString).substring(with: selection)
                        let results = try searchEngine.findAll(pattern: request.searchText, in: selectedText, options: options)

                        if !results.isEmpty {
                            // Replace the selection
                            let newText = try searchEngine.replace(
                                pattern: request.searchText,
                                replacement: request.replaceText,
                                in: selectedText,
                                options: options
                            )

                            // Ensure text view is first responder for proper undo tracking
                            textView.window?.makeFirstResponder(textView)

                            // Update text using proper undo registration
                            if textView.shouldChangeText(in: selection, replacementString: newText) {
                                textView.replaceCharacters(in: selection, with: newText)
                                textView.didChangeText()
                            }

                            // Note: syncTextFromView is automatically called by textDidChange delegate
                            // Don't call it here as it interferes with undo

                            // Clear stored search results as they're now invalid after text modification
                            currentSearchResults = []
                            currentMatchIndex = 0

                            // Note: Syntax highlighting will be handled by the debounced timer in textDidChange
                            // Don't apply it here to keep replace operation instant

                            // Show notification for single replacement
                            NotificationCenter.default.post(
                                name: .showReplaceNotification,
                                object: ReplaceNotificationInfo(count: 1, isReplaceAll: false)
                            )
                        }
                    }

                    // Find next match (this will do a fresh search with new results)
                    performFind(textView: textView, request: FindRequest(
                        searchText: request.searchText,
                        caseSensitive: request.caseSensitive,
                        wholeWord: request.wholeWord,
                        useRegex: request.useRegex
                    ), forward: true)
                }
            } catch {
                // Silent failure - no error beep
            }
        }
    }
}

// MARK: - Find Match Info

struct FindMatchInfo {
    let currentMatch: Int
    let totalMatches: Int
}

struct ReplaceNotificationInfo {
    let count: Int
    let isReplaceAll: Bool
}

#Preview("Editor - Python Code") {
    let engine = TextEngine(initialText: """
    #!/usr/bin/env python3

    def hello_world():
        print("Hello, World!")
        return True

    if __name__ == "__main__":
        hello_world()
    """)

    let docInfo = DocumentManager.DocumentInfo(
        url: URL(fileURLWithPath: "/Users/test/hello.py"),
        format: .plainText,
        encoding: .utf8,
        isRemote: false
    )

    EditorView(textEngine: engine, documentInfo: docInfo)
        .frame(height: 400)
}

#Preview("Editor - Bash Script") {
    let engine = TextEngine(initialText: """
    #!/bin/bash

    echo "Starting script..."

    for i in {1..5}; do
        echo "Iteration $i"
    done

    echo "Done!"
    """)

    let docInfo = DocumentManager.DocumentInfo(
        url: URL(fileURLWithPath: "/Users/test/script.sh"),
        format: .shell,
        encoding: .utf8,
        isRemote: false
    )

    EditorView(textEngine: engine, documentInfo: docInfo)
        .frame(height: 400)
}

#Preview("Editor - Empty") {
    let engine = TextEngine()
    EditorView(textEngine: engine, documentInfo: nil)
        .frame(height: 400)
}

// MARK: - Custom Text View

/// Custom NSTextView subclass that supports customizable cursor appearance
class CustomTextView: NSTextView {

    var cursorType: AppPreferences.CursorType = .line
    var cursorBlinks: Bool = true
    var actualCursorColor: NSColor = .textColor

    private var blinkTimer: Timer?
    private var cursorVisible = true
    private var cursorView: NSView?
    private var isUpdatingCursor = false

    // Current line highlighting
    var showCurrentLineHighlight: Bool = false
    var currentLineHighlightColor: NSColor = NSColor.systemYellow.withAlphaComponent(0.15)

    // Completion state (internal so Coordinator can access)
    var completionController: CompletionWindowController?
    var completionStartOffset: Int = 0
    var completionPrefix: String = ""
    var isShowingCompletions: Bool = false
    var documentURL: URL?  // Track document URL for file type detection

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        // Hide system cursor by making it transparent
        self.insertionPointColor = .clear
        setupCursorView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // Hide system cursor by making it transparent
        self.insertionPointColor = .clear
        setupCursorView()
    }

    private func setupCursorView() {
        // Create a custom view to draw the cursor
        let cursor = NSView(frame: NSRect(x: 0, y: 0, width: 4, height: 20))
        cursor.wantsLayer = true
        cursor.layer?.backgroundColor = actualCursorColor.cgColor
        cursorView = cursor
        addSubview(cursor)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setupBlinkTimer()

        // Custom completion window disabled - using native NSTextView completion instead
        // if completionController == nil {
        //     setupCompletionController()
        // }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            blinkTimer?.invalidate()
            blinkTimer = nil
        }
    }

    private func setupBlinkTimer() {
        blinkTimer?.invalidate()
        blinkTimer = nil

        // Initial cursor position
        cursorVisible = true
        updateCursorViewPosition()

        if cursorBlinks {
            // Blink every 0.53 seconds (standard macOS blink rate)
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.cursorVisible.toggle()
                self.cursorView?.isHidden = !self.cursorVisible
            }
        } else {
            // Solid cursor - no timer needed, just show it
            cursorView?.isHidden = false
        }
    }

    // MARK: - Completion Setup

    private func setupCompletionController() {
        print("DEBUG: setupCompletionController called")
        completionController = CompletionWindowController()

        // NO CALLBACKS - use NotificationCenter to avoid autorelease pool issues
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CompletionItemSelected"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let controller = self.completionController,
                  let userInfo = notification.userInfo,
                  let index = userInfo["index"] as? Int,
                  index < controller.items.count else {
                return
            }
            print("DEBUG: CompletionItemSelected notification received for index: \(index)")
            let item = controller.items[index]
            self.insertCompletion(item)
            controller.dismiss()
            self.isShowingCompletions = false
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CompletionWindowDismissed"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("DEBUG: CompletionWindowDismissed notification received")
            self?.isShowingCompletions = false
        }
    }

    private func updateCursorViewPosition() {
        // Prevent reentrant calls
        guard !isUpdatingCursor else { return }
        isUpdatingCursor = true
        defer { isUpdatingCursor = false }

        guard let cursorView = cursorView,
              let layoutManager = layoutManager,
              let textContainer = textContainer,
              window?.firstResponder == self else {
            cursorView?.isHidden = true
            return
        }

        let selectedRange = self.selectedRange()
        guard selectedRange.length == 0 else {
            cursorView.isHidden = true
            return
        }

        // Default font height
        let fontHeight = (font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)).boundingRectForFont.height

        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var cursorHeight: CGFloat = fontHeight

        // Get number of glyphs
        let numberOfGlyphs = layoutManager.numberOfGlyphs

        if numberOfGlyphs == 0 {
            // Completely empty document
            cursorX = textContainer.lineFragmentPadding
            cursorY = 0
            cursorHeight = fontHeight
        } else if selectedRange.location >= string.count {
            // At or beyond the end of text
            // Get the last character's position and put cursor after it
            let lastCharIndex = max(0, string.count - 1)
            let lastGlyphIndex = layoutManager.glyphIndexForCharacter(at: lastCharIndex)
            let lastLineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyphIndex, effectiveRange: nil)
            let lastGlyphLocation = layoutManager.location(forGlyphAt: lastGlyphIndex)

            // Check if last character is a newline
            if lastCharIndex < string.count {
                let lastCharIndex = string.index(string.startIndex, offsetBy: lastCharIndex)
                let lastChar = string[lastCharIndex]

                if lastChar == "\n" || lastChar == "\r" {
                    // Position on the next line
                    cursorX = textContainer.lineFragmentPadding
                    cursorY = lastLineFragmentRect.maxY
                    cursorHeight = lastLineFragmentRect.height
                } else {
                    // Position after the last character
                    cursorX = lastLineFragmentRect.origin.x + lastGlyphLocation.x + getCharacterWidthAtCursor(glyphIndex: lastGlyphIndex)
                    cursorY = lastLineFragmentRect.origin.y
                    cursorHeight = lastLineFragmentRect.height
                }
            } else {
                cursorX = lastLineFragmentRect.origin.x + lastGlyphLocation.x
                cursorY = lastLineFragmentRect.origin.y
                cursorHeight = lastLineFragmentRect.height
            }
        } else {
            // Normal case - cursor is within existing text
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: selectedRange.location)
            let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)

            if lineFragmentRect.height > 0 {
                cursorX = lineFragmentRect.origin.x + glyphLocation.x
                cursorY = lineFragmentRect.origin.y
                cursorHeight = lineFragmentRect.height
            } else {
                // Fallback for empty line in middle of document
                cursorX = textContainer.lineFragmentPadding
                cursorY = lineFragmentRect.origin.y
                cursorHeight = fontHeight
            }
        }

        // Get character width for block/underline cursors
        let charWidth: CGFloat
        if string.count > 0 && selectedRange.location < string.count {
            let glyphIdx = layoutManager.glyphIndexForCharacter(at: selectedRange.location)
            charWidth = getCharacterWidthAtCursor(glyphIndex: glyphIdx)
        } else {
            charWidth = 8.0 // Default width for empty or end position
        }

        // Update cursor frame based on type
        switch cursorType {
        case .line:
            cursorView.frame = NSRect(x: cursorX, y: cursorY, width: 4, height: cursorHeight)
        case .block:
            cursorView.frame = NSRect(x: cursorX, y: cursorY, width: charWidth, height: cursorHeight)
        case .underline:
            cursorView.frame = NSRect(x: cursorX, y: cursorY + cursorHeight - 4, width: charWidth, height: 4)
        }

        cursorView.isHidden = !cursorVisible
    }

    deinit {
        blinkTimer?.invalidate()
    }

    func updateCursorSettings(type: AppPreferences.CursorType, blinks: Bool) {
        let settingsChanged = (self.cursorType != type) || (self.cursorBlinks != blinks)

        self.cursorType = type
        self.cursorBlinks = blinks

        if settingsChanged {
            cursorVisible = true
            setupBlinkTimer()
        }
    }

    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        // Update cursor position when selection changes
        updateCursorViewPosition()
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        // Don't dismiss completions here - let them update instead
        // The keyboard monitor will handle dismissing on non-completion keys

        // Check if we're about to complete a snippet trigger
        var willExpandSnippet = false
        var snippetToExpand: Snippet?
        var triggerStart = 0
        var triggerLength = 0

        if let insertedString = string as? String, insertedString.count == 1 {
            // Simulate what the text will be after insertion
            let currentText = self.string as NSString
            let cursorPos = selectedRange().location

            // Find the word before cursor + new character
            var wordStart = cursorPos
            while wordStart > 0 {
                let prevChar = currentText.character(at: wordStart - 1)
                let char = Character(UnicodeScalar(prevChar)!)
                if char.isWhitespace || char.isNewline {
                    break
                }
                wordStart -= 1
            }

            let potentialTrigger = currentText.substring(with: NSRange(location: wordStart, length: cursorPos - wordStart)) + insertedString

            if let snippet = SnippetManager.shared.findSnippet(for: potentialTrigger) {
                willExpandSnippet = true
                snippetToExpand = snippet
                triggerStart = wordStart
                triggerLength = potentialTrigger.count
            }
        }

        if willExpandSnippet, let snippet = snippetToExpand {
            // Don't call super - we'll handle the entire operation ourselves
            // This prevents NSTextView from creating undo entries for each character

            // Delete the trigger text if any exists
            if triggerLength > 1 {
                let deleteRange = NSRange(location: triggerStart, length: triggerLength - 1)
                if shouldChangeText(in: deleteRange, replacementString: "") {
                    replaceCharacters(in: deleteRange, with: "")
                }
            }

            // Insert the expansion at the trigger start position
            if shouldChangeText(in: NSRange(location: triggerStart, length: 0), replacementString: snippet.expansion) {
                undoManager?.registerUndo(withTarget: self) { [snippet, triggerStart] target in
                    if target.shouldChangeText(in: NSRange(location: triggerStart, length: snippet.expansion.count), replacementString: "") {
                        target.replaceCharacters(in: NSRange(location: triggerStart, length: snippet.expansion.count), with: "")
                        target.didChangeText()

                        // Register redo
                        target.undoManager?.registerUndo(withTarget: target) { redoTarget in
                            if redoTarget.shouldChangeText(in: NSRange(location: triggerStart, length: 0), replacementString: snippet.expansion) {
                                redoTarget.replaceCharacters(in: NSRange(location: triggerStart, length: 0), with: snippet.expansion)
                                redoTarget.didChangeText()
                                redoTarget.updateCursorViewPosition()
                            }
                        }

                        target.updateCursorViewPosition()
                    }
                }
                undoManager?.setActionName("Snippet Expansion")

                replaceCharacters(in: NSRange(location: triggerStart, length: 0), with: snippet.expansion)
                didChangeText()
            }
        } else {
            // Normal character insertion
            super.insertText(string, replacementRange: replacementRange)
        }

        // Auto-trigger completion after typing if enabled
        if AppPreferences.shared.enableAutoCompletion,
           let insertedString = string as? String,
           let char = insertedString.last {
            checkAutoCompletionTrigger(after: char)
        }

        // Update cursor position after text insertion
        updateCursorViewPosition()
    }

    override func deleteBackward(_ sender: Any?) {
        super.deleteBackward(sender)
        // Update cursor position after deletion
        updateCursorViewPosition()
    }

    // MARK: - Completion

    private func checkAutoCompletionTrigger(after character: Character) {
        // Get current word being typed
        let cursorPos = selectedRange().location
        let wordRange = getWordRange(at: cursorPos)
        let word = (string as NSString).substring(with: wordRange)

        print("DEBUG: checkAutoCompletionTrigger - cursorPos: \(cursorPos), wordRange: \(wordRange), word: '\(word)'")

        // Trigger if word length >= 2 and provider says auto-trigger is OK
        guard word.count >= AppPreferences.shared.completionTriggerLength else {
            print("DEBUG: Word too short (\(word.count) chars), not triggering")
            return
        }

        if let provider = currentCompletionProvider(),
           provider.shouldTriggerAutomatically(after: character) {
            print("DEBUG: Auto-triggering native completion for word: '\(word)'")
            // Trigger native NSTextView completion
            DispatchQueue.main.async { [weak self] in
                self?.complete(nil)
            }
        }
    }

    func showCompletionsManually() {
        // Triggered by Esc or Ctrl+Space
        let cursorPos = selectedRange().location
        let wordRange = getWordRange(at: cursorPos)
        let word = (string as NSString).substring(with: wordRange)

        showCompletions(for: word, at: wordRange.location)
    }

    private func showCompletions(for prefix: String, at offset: Int) {
        guard let provider = currentCompletionProvider() else { return }

        print("DEBUG: showCompletions called with prefix: '\(prefix)', offset: \(offset)")

        let cursorLine = getCurrentLine()
        let items = provider.completions(
            for: prefix,
            at: selectedRange().location,
            in: string,
            cursorLine: cursorLine
        )

        print("DEBUG: provider.completions returned \(items.count) items")
        if items.count > 0 {
            print("DEBUG: First 3 items: \(items.prefix(3).map { $0.text })")
        }

        guard !items.isEmpty else {
            print("DEBUG: No items, not showing completions")
            return
        }

        completionPrefix = prefix
        completionStartOffset = offset
        isShowingCompletions = true

        print("DEBUG: Setting completionPrefix='\(prefix)', completionStartOffset=\(offset)")
        print("DEBUG: Calling completionController.show() with \(items.count) items")

        // Get cursor rect for positioning
        let cursorRect = getCursorRect()
        completionController?.show(items: items, at: cursorRect, in: self)
    }

    func insertCompletion(_ item: CompletionItem) {
        print("DEBUG: insertCompletion called with item.text: '\(item.text)'")
        print("DEBUG: completionPrefix: '\(completionPrefix)', completionStartOffset: \(completionStartOffset)")

        // Replace the prefix with the full completion
        let deleteRange = NSRange(
            location: completionStartOffset,
            length: completionPrefix.count
        )

        print("DEBUG: deleteRange: \(deleteRange), replacing with: '\(item.text)'")

        if shouldChangeText(in: deleteRange, replacementString: item.text) {
            replaceCharacters(in: deleteRange, with: item.text)
            didChangeText()
            print("DEBUG: Successfully inserted '\(item.text)'")
        } else {
            print("DEBUG: shouldChangeText returned false")
        }

        isShowingCompletions = false
        updateCursorViewPosition()
    }

    private func currentCompletionProvider() -> CompletionProvider? {
        // Detect file type from shebang or document URL
        let fileType = detectFileType()

        // Return appropriate completion provider based on detected type
        // BashCompletionProvider now handles all scripting languages (Python, Ruby, JS, PHP, Perl)
        switch fileType {
        case "sh", "bash", "zsh", "py", "rb", "js", "pl", "php", "":
            // All scripting languages use the unified completion provider
            // It auto-detects language from shebang and provides appropriate completions
            return BashCompletionProvider.shared

        default:
            return nil
        }
    }

    private func detectFileType() -> String {
        // Priority 1: Check shebang (first line) - most accurate for scripts
        if string.hasPrefix("#!") {
            let firstLine = string.components(separatedBy: .newlines).first ?? ""

            // Parse shebang to extract interpreter
            // Handles: #!/bin/bash, #!/usr/bin/env python3, #!/usr/bin/env node, etc.
            let shebangPattern = "^#!\\s*(?:/usr/bin/env\\s+)?(?:.*/)?([^\\s]+)"
            if let regex = try? NSRegularExpression(pattern: shebangPattern),
               let match = regex.firstMatch(in: firstLine, range: NSRange(firstLine.startIndex..., in: firstLine)),
               let interpreterRange = Range(match.range(at: 1), in: firstLine) {

                let interpreter = String(firstLine[interpreterRange])

                // Map interpreter to file type
                switch interpreter.lowercased() {
                case "bash", "sh", "zsh", "ksh", "dash":
                    return "sh"
                case "python", "python2", "python3":
                    return "py"
                case "ruby", "ruby2", "ruby3":
                    return "rb"
                case "node", "nodejs":
                    return "js"
                case "perl":
                    return "pl"
                case "php":
                    return "php"
                default:
                    return interpreter.lowercased()
                }
            }
        }

        // Priority 2: Check document URL file extension
        if let url = documentURL {
            return url.pathExtension.lowercased()
        }

        return ""
    }

    private func getWordRange(at position: Int) -> NSRange {
        var start = position
        while start > 0 {
            let char = (string as NSString).character(at: start - 1)
            let c = Character(UnicodeScalar(char)!)
            // Stop at whitespace or command separators
            if c.isWhitespace || c.isNewline || ";&|()<>".contains(c) {
                break
            }
            start -= 1
        }
        return NSRange(location: start, length: position - start)
    }

    private func getCurrentLine() -> String {
        let cursorPos = selectedRange().location
        let lineRange = (string as NSString).lineRange(
            for: NSRange(location: cursorPos, length: 0)
        )
        return (string as NSString).substring(with: lineRange)
    }

    private func getCursorRect() -> NSRect {
        guard let layoutManager = layoutManager,
              let _ = textContainer else {
            return .zero
        }

        let glyphIndex = layoutManager.glyphIndexForCharacter(at: selectedRange().location)
        let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)

        return NSRect(
            x: lineFragmentRect.origin.x + glyphLocation.x,
            y: lineFragmentRect.origin.y,
            width: 2,
            height: lineFragmentRect.height
        )
    }

    // MARK: - Snippet Expansion
    // Snippet expansion is now handled directly in insertText(_:replacementRange:)

    // Override to completely prevent default cursor from drawing
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        // Do nothing - we use a custom NSView for cursor display
        // Don't call super - completely suppress default cursor
    }

    // Prevent system from managing cursor blink state
    override func updateInsertionPointStateAndRestartTimer(_ restartFlag: Bool) {
        // Don't call super - we manage our own cursor
    }

    private func getCharacterWidthAtCursor(glyphIndex: Int) -> CGFloat {
        guard let layoutManager = layoutManager,
              let _ = textContainer,
              glyphIndex >= 0,
              glyphIndex < layoutManager.numberOfGlyphs else {
            return 8.0
        }

        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

        guard charIndex >= 0 && charIndex < string.count else {
            return (font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)).maximumAdvancement.width
        }

        guard let index = string.index(string.startIndex, offsetBy: charIndex, limitedBy: string.endIndex) else {
            return 8.0
        }

        let char = string[index]
        let attrs: [NSAttributedString.Key: Any] = [.font: font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)]
        let charSize = String(char).size(withAttributes: attrs)

        return max(charSize.width, 8.0)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            // Force redraw to show cursor
            setNeedsDisplay(visibleRect)
        }
        return result
    }

    // Override to draw current line highlight
    override func drawBackground(in rect: NSRect) {
        // First draw the default background
        super.drawBackground(in: rect)

        // Then draw current line highlight on top
        guard let layoutManager = layoutManager else {
            return
        }

        if showCurrentLineHighlight && window?.firstResponder == self {
            guard textContainer != nil else { return }

            let selectedRange = self.selectedRange()

            // Get the glyph index and line fragment rect
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: selectedRange.location)
            var lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            // Adjust for text container origin
            let origin = textContainerOrigin
            lineFragmentRect.origin.y += origin.y

            // Create full-width highlight
            let highlightRect = NSRect(
                x: 0,
                y: lineFragmentRect.origin.y,
                width: bounds.width,
                height: lineFragmentRect.height
            )

            currentLineHighlightColor.setFill()
            NSBezierPath(rect: highlightRect).fill()
        }
    }

    // MARK: - Completions

    override func completions(forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]? {
        // Use native NSTextView completion with our bash providers
        guard isAutomaticTextCompletionEnabled else {
            return nil
        }

        guard charRange.location != NSNotFound,
              charRange.location + charRange.length <= string.count else {
            return nil
        }

        let partialWord = (string as NSString).substring(with: charRange)

        // Minimum length to trigger completions
        guard partialWord.count >= AppPreferences.shared.completionTriggerLength else {
            return nil
        }

        // Use bash completion provider for .sh files
        if let provider = currentCompletionProvider() {
            let cursorLine = getCurrentLine()
            let items = provider.completions(
                for: partialWord,
                at: charRange.location,
                in: string,
                cursorLine: cursorLine
            )

            // Convert CompletionItems to strings for native completion
            let completions = items.map { $0.text }

            index.pointee = -1 // No default selection
            return completions.isEmpty ? nil : completions
        }

        // Fallback: Extract words from document
        let words = string.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count >= partialWord.count }
            .filter { $0.lowercased().hasPrefix(partialWord.lowercased()) }
            .filter { $0.lowercased() != partialWord.lowercased() }

        let uniqueWords = Array(Set(words)).sorted { $0.lowercased() < $1.lowercased() }
        let suggestions = Array(uniqueWords.prefix(10))

        index.pointee = -1
        return suggestions.isEmpty ? nil : suggestions
    }

    // MARK: - Printing Support

    override func printView(_ sender: Any?) {
        // Create print info
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false

        // Create print operation
        let printOperation = NSPrintOperation(view: self, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true

        // Run print operation
        if let window = self.window {
            printOperation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            printOperation.run()
        }
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Enable print menu item
        if menuItem.action == #selector(printView(_:)) {
            return true
        }
        return super.validateMenuItem(menuItem)
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

}
