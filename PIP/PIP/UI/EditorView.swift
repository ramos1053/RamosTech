import SwiftUI
import AppKit

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

        // Disable automatic substitutions (BBEdit behavior)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = preferences.enablePredictiveCompletion
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

        // Ensure scroll view starts at (0,0) position
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))

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

        // Apply initial syntax highlighting if enabled
        if preferences.enableSyntaxColoring {
            context.coordinator.applySyntaxHighlighting(to: textView)
        }

        // Make text view first responder to enable cursor
        DispatchQueue.main.async {
            if let window = scrollView.window {
                _ = window.makeFirstResponder(textView)
            }
        }

        // Also trigger when window becomes key
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { notification in
            if let window = notification.object as? NSWindow {
                _ = window.makeFirstResponder(textView)
                textView.setNeedsDisplay(textView.visibleRect)
            }
        }

        // Listen for scroll to left notification (for header insertion)
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ScrollToLeft"), object: nil, queue: .main) { _ in
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollView.contentView.bounds.origin.y))
            scrollView.reflectScrolledClipView(scrollView.contentView)
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
        textView.textColor = theme.textColor.nsColor
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

        // Update predictive completion
        textView.isAutomaticTextCompletionEnabled = preferences.enablePredictiveCompletion

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
        if textView.string != textEngine.text {
            _ = textView.selectedRange()
            textView.string = textEngine.text

            // Restore cursor position
            let newPosition = min(textEngine.cursorPosition, textView.string.count)
            textView.setSelectedRange(NSRange(location: newPosition, length: 0))

            // Ensure scroll position is aligned to left if text is short
            // Use async to ensure this happens after cursor positioning completes
            if textView.string.count < 1000 {
                DispatchQueue.main.async {
                    scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollView.contentView.bounds.origin.y))
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            }
        } else {
            // Text hasn't changed, but cursor position might have - sync it
            let currentCursorPos = textView.selectedRange().location
            if currentCursorPos != textEngine.cursorPosition {
                let newPosition = min(textEngine.cursorPosition, textView.string.count)
                textView.setSelectedRange(NSRange(location: newPosition, length: 0))

                // Also ensure scroll position is aligned to left
                // Use async to ensure this happens after cursor positioning completes
                if textView.string.count < 1000 {
                    DispatchQueue.main.async {
                        scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollView.contentView.bounds.origin.y))
                        scrollView.reflectScrolledClipView(scrollView.contentView)
                    }
                }
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

        // Update syntax highlighting when preference changes
        if preferences.enableSyntaxColoring {
            context.coordinator.applySyntaxHighlighting(to: textView)
        } else {
            context.coordinator.removeSyntaxHighlighting(from: textView)
        }
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

    class Coordinator: NSObject, NSTextViewDelegate {
        let textEngine: TextEngine
        var documentInfo: DocumentManager.DocumentInfo?
        weak var scrollView: NSScrollView?
        weak var textView: CustomTextView?
        private var currentLanguage: SyntaxHighlighter.Language = .plainText

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
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            Task { @MainActor in
                // Sync text back to engine
                let newText = textView.string
                if newText != textEngine.text {
                    textEngine.syncTextFromView(newText)
                    textEngine.cursorPosition = textView.selectedRange().location
                }

                // Apply syntax highlighting if enabled
                if AppPreferences.shared.enableSyntaxColoring {
                    applySyntaxHighlighting(to: textView)
                } else {
                    removeSyntaxHighlighting(from: textView)
                }

                // Update line numbers
                scrollView?.verticalRulerView?.needsDisplay = true
            }
        }

        @MainActor
        func applySyntaxHighlighting(to textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }

            let text = textView.string
            let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            let theme = AppPreferences.shared.currentTheme

            // Create highlighter and set language
            let highlighter = SyntaxHighlighter()
            highlighter.setLanguage(currentLanguage)

            // Get attributed string with syntax colors
            let attributedString = highlighter.attributedString(for: text, baseFont: font, theme: theme)

            // Store selection
            let savedSelection = textView.selectedRange()

            // Replace text storage contents
            textStorage.beginEditing()
            textStorage.setAttributedString(attributedString)
            textStorage.endEditing()

            // Restore selection
            textView.setSelectedRange(savedSelection)
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
            // Return false to let NSTextView handle all commands with standard macOS behavior
            // This gives us BBEdit-like editing with proper single-character deletion,
            // selection handling, and all standard text navigation
            return false
        }
    }
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

        // Update cursor position after text insertion
        updateCursorViewPosition()
    }

    override func deleteBackward(_ sender: Any?) {
        super.deleteBackward(sender)
        // Update cursor position after deletion
        updateCursorViewPosition()
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
            guard let textContainer = textContainer else { return }

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
        // Only provide completions if enabled in preferences
        guard isAutomaticTextCompletionEnabled else {
            return nil
        }

        // Get the partial word being typed
        guard charRange.location != NSNotFound,
              charRange.location + charRange.length <= string.count else {
            return nil
        }

        let partialWord = (string as NSString).substring(with: charRange)

        // Minimum length to trigger completions
        guard partialWord.count >= 2 else {
            return nil
        }

        // Extract all words from the document
        let words = string.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count >= partialWord.count }
            .filter { $0.lowercased().hasPrefix(partialWord.lowercased()) }
            .filter { $0.lowercased() != partialWord.lowercased() } // Don't suggest the exact word

        // Remove duplicates and sort
        let uniqueWords = Array(Set(words)).sorted { $0.lowercased() < $1.lowercased() }

        // Limit to top 10 suggestions
        let suggestions = Array(uniqueWords.prefix(10))

        index.pointee = -1 // No default selection
        return suggestions.isEmpty ? nil : suggestions
    }

}
