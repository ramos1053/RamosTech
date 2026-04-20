//
//  HotkeyManager.swift
//  Snipster
//
//  Created by RamosTech on 1/8/26.
//

import Foundation
import Combine
import Carbon
import AppKit

/// Manages global hotkey registration and conflict detection
/// Uses Carbon APIs for hotkey registration (similar to KeyboardShortcuts library)
@MainActor
class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    // UserDefaults keys
    private let hotkeyEnabledKey = "snipster.hotkey.enabled"
    private let hotkeyKeyCodeKey = "snipster.hotkey.keyCode"
    private let hotkeyModifiersKey = "snipster.hotkey.modifiers"

    // Default hotkey: Cmd+Shift+S
    private let defaultKeyCode: UInt32 = 1 // 'S' key
    private let defaultModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: hotkeyEnabledKey)
            if isEnabled {
                registerHotkey()
            } else {
                unregisterHotkey()
            }
        }
    }

    @Published var currentKeyCode: UInt32
    @Published var currentModifiers: UInt32

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {
        // Load saved preferences
        self.isEnabled = UserDefaults.standard.object(forKey: hotkeyEnabledKey) as? Bool ?? true
        self.currentKeyCode = UserDefaults.standard.object(forKey: hotkeyKeyCodeKey) as? UInt32 ?? defaultKeyCode
        self.currentModifiers = UserDefaults.standard.object(forKey: hotkeyModifiersKey) as? UInt32 ?? defaultModifiers

        setupEventHandler()

        if isEnabled {
            registerHotkey()
        }
    }

    // MARK: - Hotkey Registration

    private func setupEventHandler() {
        let eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]

        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (eventHandlerCall, event, userData) -> OSStatus in
                guard let manager = userData?.load(as: HotkeyManager.self) else {
                    return OSStatus(eventNotHandledErr)
                }

                Task { @MainActor in
                    manager.hotkeyPressed()
                }

                return noErr
            },
            eventSpec.count,
            eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )

        if status == noErr {
            self.eventHandler = handler
        }
    }

    private func registerHotkey() {
        // Unregister existing hotkey first
        unregisterHotkey()

        var hotKeyID = EventHotKeyID(signature: OSType(0x53415253), id: 1) // 'SARS' signature
        let modifiers = currentModifiers

        // Use GetApplicationEventTarget() which works globally
        // The hotkey will be delivered to our event handler regardless of which app is active
        let status = RegisterEventHotKey(
            currentKeyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyNoOptions),
            &hotKeyRef
        )

        if status != noErr {
            print("Failed to register hotkey: \(status)")
        } else {
            print("Hotkey registered successfully")
        }
    }

    private func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func hotkeyPressed() {
        // Toggle the Spotlight window
        SpotlightWindowManager.shared.toggle()
    }

    // MARK: - Hotkey Configuration

    /// Update the hotkey combination
    func updateHotkey(keyCode: UInt32, modifiers: UInt32) throws {
        // Check for conflicts
        if let conflict = checkForConflicts(keyCode: keyCode, modifiers: modifiers) {
            throw HotkeyError.conflict(conflict)
        }

        // Save new hotkey
        self.currentKeyCode = keyCode
        self.currentModifiers = modifiers

        UserDefaults.standard.set(keyCode, forKey: hotkeyKeyCodeKey)
        UserDefaults.standard.set(modifiers, forKey: hotkeyModifiersKey)

        // Re-register if enabled
        if isEnabled {
            registerHotkey()
        }
    }

    /// Reset to default hotkey
    func resetToDefault() {
        try? updateHotkey(keyCode: defaultKeyCode, modifiers: defaultModifiers)
    }

    // MARK: - Conflict Detection

    /// Check if a hotkey conflicts with system shortcuts
    func checkForConflicts(keyCode: UInt32, modifiers: UInt32) -> String? {
        let carbonModifiers = modifiers

        // Common system shortcuts to check
        let systemShortcuts: [(keyCode: UInt32, modifiers: UInt32, name: String)] = [
            (49, UInt32(cmdKey), "Spotlight (Cmd+Space)"),
            (48, UInt32(cmdKey), "App Switcher (Cmd+Tab)"),
            (12, UInt32(cmdKey), "Quit (Cmd+Q)"),
            (13, UInt32(cmdKey), "Close Window (Cmd+W)"),
            (45, UInt32(cmdKey), "New Window (Cmd+N)"),
            (8, UInt32(cmdKey | shiftKey), "Screenshot (Cmd+Shift+4)"),
            (6, UInt32(cmdKey | shiftKey), "Screenshot Selection (Cmd+Shift+3)"),
            (0, UInt32(cmdKey), "Select All (Cmd+A)"),
            (8, UInt32(cmdKey), "Copy (Cmd+C)"),
            (9, UInt32(cmdKey), "Paste (Cmd+V)"),
            (7, UInt32(cmdKey), "Cut (Cmd+X)"),
            (15, UInt32(cmdKey), "Redo (Cmd+R)"),
            (6, UInt32(cmdKey), "Undo (Cmd+Z)"),
            (49, UInt32(controlKey), "Spotlight Alternative (Ctrl+Space)"),
        ]

        // Check against known system shortcuts
        for shortcut in systemShortcuts {
            if shortcut.keyCode == keyCode && shortcut.modifiers == carbonModifiers {
                return shortcut.name
            }
        }

        // Check for single modifier or no modifier (dangerous)
        let hasCmdKey = (carbonModifiers & UInt32(cmdKey)) != 0
        let hasCtrlKey = (carbonModifiers & UInt32(controlKey)) != 0
        let hasOptKey = (carbonModifiers & UInt32(optionKey)) != 0
        let hasShiftKey = (carbonModifiers & UInt32(shiftKey)) != 0

        let modifierCount = [hasCmdKey, hasCtrlKey, hasOptKey, hasShiftKey].filter { $0 }.count

        if modifierCount == 0 {
            return "No modifiers (unsafe - would intercept all key presses)"
        }

        if modifierCount == 1 && hasShiftKey {
            return "Shift only (unsafe - conflicts with text input)"
        }

        return nil
    }

    /// Get a human-readable description of the current hotkey
    func getHotkeyDescription() -> String {
        var parts: [String] = []

        let modifiers = currentModifiers

        if (modifiers & UInt32(controlKey)) != 0 {
            parts.append("⌃")
        }
        if (modifiers & UInt32(optionKey)) != 0 {
            parts.append("⌥")
        }
        if (modifiers & UInt32(shiftKey)) != 0 {
            parts.append("⇧")
        }
        if (modifiers & UInt32(cmdKey)) != 0 {
            parts.append("⌘")
        }

        // Map key code to character
        let keyChar = keyCodeToString(currentKeyCode)
        parts.append(keyChar)

        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        // Map common key codes to characters
        let keyMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P",
            37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            49: "Space", 48: "Tab", 51: "Delete", 53: "Escape",
            36: "Return", 76: "Enter"
        ]

        return keyMap[keyCode] ?? "Key \(keyCode)"
    }

    // MARK: - Cleanup

    nonisolated deinit {
        // Note: Cannot call @MainActor methods from deinit
        // Hotkey will be automatically cleaned up when the app terminates
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }
}

// MARK: - Errors

enum HotkeyError: LocalizedError {
    case conflict(String)

    var errorDescription: String? {
        switch self {
        case .conflict(let shortcutName):
            return "Keyboard shortcut conflicts with \(shortcutName). Please choose a different combination."
        }
    }
}

// MARK: - Hotkey Recorder View Model

/// View model for recording hotkeys in the UI
@MainActor
class HotkeyRecorderViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordedKeyCode: UInt32?
    @Published var recordedModifiers: UInt32?
    @Published var errorMessage: String?

    private var eventMonitor: Any?

    func startRecording() {
        isRecording = true
        recordedKeyCode = nil
        recordedModifiers = nil
        errorMessage = nil

        // Monitor for key presses
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyPress(event)
            return nil // Consume the event
        }
    }

    func stopRecording() {
        isRecording = false

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyPress(_ event: NSEvent) {
        let keyCode = event.keyCode
        let flags = event.modifierFlags

        // Convert NSEvent modifiers to Carbon modifiers
        var carbonModifiers: UInt32 = 0

        if flags.contains(.command) {
            carbonModifiers |= UInt32(cmdKey)
        }
        if flags.contains(.control) {
            carbonModifiers |= UInt32(controlKey)
        }
        if flags.contains(.option) {
            carbonModifiers |= UInt32(optionKey)
        }
        if flags.contains(.shift) {
            carbonModifiers |= UInt32(shiftKey)
        }

        // Require at least one modifier
        guard carbonModifiers != 0 else {
            errorMessage = "Please use at least one modifier key (⌘, ⌃, ⌥, or ⇧)"
            return
        }

        // Check for conflicts
        if let conflict = HotkeyManager.shared.checkForConflicts(keyCode: UInt32(keyCode), modifiers: carbonModifiers) {
            errorMessage = "Conflicts with \(conflict)"
            return
        }

        // Valid hotkey recorded
        recordedKeyCode = UInt32(keyCode)
        recordedModifiers = carbonModifiers
        errorMessage = nil

        stopRecording()
    }

    func applyRecordedHotkey() throws {
        guard let keyCode = recordedKeyCode,
              let modifiers = recordedModifiers else {
            throw HotkeyError.conflict("No hotkey recorded")
        }

        try HotkeyManager.shared.updateHotkey(keyCode: keyCode, modifiers: modifiers)
    }
}
