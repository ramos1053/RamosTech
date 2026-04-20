//
//  TextExpansionMonitor.swift
//  Snipster
//
//  Created by Alan Ramos on 12/16/25.
//

import Foundation
import AppKit
import Carbon
import Combine

@MainActor
class TextExpansionMonitor: ObservableObject {
    static let shared = TextExpansionMonitor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Thread-safe properties accessed from event tap callback
    private let accessQueue = DispatchQueue(label: "com.snipster.eventTap", attributes: .concurrent)
    nonisolated(unsafe) private var _typedBuffer: String = ""
    nonisolated(unsafe) private var _snippets: [Snippet] = []
    nonisolated(unsafe) private var _isExpanding: Bool = false

    nonisolated private var typedBuffer: String {
        get { accessQueue.sync { _typedBuffer } }
        set { accessQueue.sync(flags: .barrier) { self._typedBuffer = newValue } }
    }

    nonisolated private var snippets: [Snippet] {
        get { accessQueue.sync { _snippets } }
        set { accessQueue.sync(flags: .barrier) { self._snippets = newValue } }
    }

    nonisolated private var isExpanding: Bool {
        get { accessQueue.sync { _isExpanding } }
        set { accessQueue.sync(flags: .barrier) { self._isExpanding = newValue } }
    }

    @Published var isEnabled: Bool = false
    @Published var hasAccessibilityPermission: Bool = false

    private var permissionTimer: Timer?

    private init() {
        checkAccessibilityPermission()
        startPermissionMonitoring()
    }

    func updateSnippets(_ newSnippets: [Snippet]) {
        snippets = newSnippets.filter { !$0.triggerSequence.isEmpty }
    }

    func checkAccessibilityPermission() {
        let previousState = hasAccessibilityPermission
        hasAccessibilityPermission = AXIsProcessTrusted()

        // Only respond if state changed
        if previousState != hasAccessibilityPermission {
            // Automatically respond to permission changes
            if hasAccessibilityPermission && !isEnabled {
                startMonitoring()
            } else if !hasAccessibilityPermission && isEnabled {
                stopMonitoring()
            }
        }
    }

    private func startPermissionMonitoring() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                self?.checkAccessibilityPermission()
            }
        }
    }

    func requestAccessibilityPermission() {
        openAccessibilitySettings()
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func startMonitoring() {
        guard !isEnabled else { return }
        guard hasAccessibilityPermission else {
            requestAccessibilityPermission()
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }

                let monitor = Unmanaged<TextExpansionMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        self.eventTap = eventTap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = runLoopSource

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        isEnabled = true
    }

    func stopMonitoring() {
        guard isEnabled else { return }

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }

        isEnabled = false
        typedBuffer = ""
    }

    func restartMonitoring() {
        stopMonitoring()
        checkAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.hasAccessibilityPermission {
                self.startMonitoring()
            }
        }
    }

    nonisolated private func getKeyboardEventString(from event: CGEvent) -> String? {
        let maxLength = 1
        var actualLength = 0
        var unicodeString = [UniChar](repeating: 0, count: maxLength)

        event.keyboardGetUnicodeString(
            maxStringLength: maxLength,
            actualStringLength: &actualLength,
            unicodeString: &unicodeString
        )

        return String(utf16CodeUnits: unicodeString, count: actualLength)
    }

    nonisolated private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Ignore events during expansion to prevent feedback loop
        if isExpanding {
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        // Get the typed character
        guard let eventString = getKeyboardEventString(from: event) else {
            return Unmanaged.passRetained(event)
        }

        // Check for special keys that should clear the buffer
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Clear buffer on Enter, Tab, Esc, or arrow keys, space
        if keyCode == 36 || keyCode == 48 || keyCode == 49 || keyCode == 53 ||
           keyCode == 123 || keyCode == 124 || keyCode == 125 || keyCode == 126 {
            typedBuffer = ""
            return Unmanaged.passRetained(event)
        }

        // Handle backspace/delete
        if keyCode == 51 {
            if !typedBuffer.isEmpty {
                typedBuffer.removeLast()
            }
            return Unmanaged.passRetained(event)
        }

        // Add character to buffer
        typedBuffer += eventString

        // Keep buffer to reasonable size (max 50 characters)
        if typedBuffer.count > 50 {
            typedBuffer = String(typedBuffer.suffix(50))
        }

        // Check for trigger matches
        if let matchedSnippet = findMatchingSnippet() {
            typedBuffer = ""
            isExpanding = true
            // Access stored properties directly to avoid MainActor isolation issues
            let charsToDelete = matchedSnippet.triggerPrefix.count + matchedSnippet.triggerSequence.count
            DispatchQueue.global(qos: .userInitiated).async {
                Thread.sleep(forTimeInterval: 0.05)
                self.expandSnippetSync(matchedSnippet, triggerLength: charsToDelete)
                self.isExpanding = false
            }
            return Unmanaged.passRetained(event)
        }

        return Unmanaged.passRetained(event)
    }

    nonisolated private func findMatchingSnippet() -> Snippet? {
        for snippet in snippets {
            // Access stored properties directly to avoid MainActor isolation issues
            let fullTrigger = snippet.triggerPrefix + snippet.triggerSequence
            if !fullTrigger.isEmpty && typedBuffer.hasSuffix(fullTrigger) {
                return snippet
            }
        }
        return nil
    }

    nonisolated private func deleteCharacters(count: Int) {
        let source = CGEventSource(stateID: .hidSystemState)

        for _ in 0..<count {
            // Create backspace key down event
            if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true) {
                keyDown.post(tap: .cghidEventTap)
            }

            // Create backspace key up event
            if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false) {
                keyUp.post(tap: .cghidEventTap)
            }
        }
    }

    nonisolated private func expandSnippetSync(_ snippet: Snippet, triggerLength: Int) {
        if triggerLength > 0 {
            deleteCharacters(count: triggerLength)
            Thread.sleep(forTimeInterval: 0.1)
        }

        let processor = SnippetVariableProcessor.shared
        let processedContent = processor.processVariables(in: snippet.content)

        let (finalContent, cursorOffset) = processor.extractCursorPosition(from: processedContent)

        typeText(finalContent)

        if let offset = cursorOffset {
            moveCursorBack(by: finalContent.count - offset)
        }
    }

    nonisolated private func moveCursorBack(by count: Int) {
        guard count > 0 else { return }

        let source = CGEventSource(stateID: .hidSystemState)

        for _ in 0..<count {
            // Send left arrow key
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 123, keyDown: true) // 123 is left arrow
            keyDown?.post(tap: .cghidEventTap)

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 123, keyDown: false)
            keyUp?.post(tap: .cghidEventTap)

            Thread.sleep(forTimeInterval: 0.001)
        }
    }

    nonisolated private func typeText(_ text: String) {
        // Use pasteboard to insert text instantly
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            let previousContents = pasteboard.string(forType: .string)

            // Copy snippet content to clipboard
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            // Simulate Cmd+V to paste
            let source = CGEventSource(stateID: .hidSystemState)

            // Press Cmd+V
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // 9 is 'v'
            keyDown?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
            keyUp?.flags = .maskCommand
            keyUp?.post(tap: .cghidEventTap)

            // Restore previous clipboard contents after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let previous = previousContents {
                    pasteboard.clearContents()
                    pasteboard.setString(previous, forType: .string)
                }
            }
        }
    }
}
