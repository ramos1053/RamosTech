//
//  HotkeyManager.swift
//  Snipster
//
//  Created by RamosTech on 1/8/26.
//

import Foundation
import Combine
import Carbon

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
    // nonisolated(unsafe) — deinit (always nonisolated for a class) needs to
    // release this Carbon handle; in practice it's only ever otherwise
    // touched from MainActor-isolated registration code, and deinit only
    // runs once the last reference is gone, so there's no real concurrent
    // access to guard against.
    nonisolated(unsafe) private var eventHandler: EventHandlerRef?

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

        let hotKeyID = EventHotKeyID(signature: OSType(0x53415253), id: 1) // 'SARS' signature
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
        return HotkeyKeyCatalog.allKeysByCode[keyCode] ?? "Key \(keyCode)"
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

// MARK: - Key Catalog

/// One selectable key in the hotkey picker.
struct HotkeyKeyOption: Identifiable, Hashable {
    let id: UInt32
    let label: String
}

/// The fixed set of keys offered by the hotkey picker, grouped for display.
/// Built from Carbon's kVK_* virtual keycode constants (the same values
/// RegisterEventHotKey expects) rather than live keypress capture — a
/// picker needs no Accessibility/Input Monitoring permission and isn't
/// subject to window-focus or event-routing quirks the way capturing a raw
/// NSEvent keyDown is.
enum HotkeyKeyCatalog {
    static let letters: [HotkeyKeyOption] = [
        .init(id: UInt32(kVK_ANSI_A), label: "A"), .init(id: UInt32(kVK_ANSI_B), label: "B"),
        .init(id: UInt32(kVK_ANSI_C), label: "C"), .init(id: UInt32(kVK_ANSI_D), label: "D"),
        .init(id: UInt32(kVK_ANSI_E), label: "E"), .init(id: UInt32(kVK_ANSI_F), label: "F"),
        .init(id: UInt32(kVK_ANSI_G), label: "G"), .init(id: UInt32(kVK_ANSI_H), label: "H"),
        .init(id: UInt32(kVK_ANSI_I), label: "I"), .init(id: UInt32(kVK_ANSI_J), label: "J"),
        .init(id: UInt32(kVK_ANSI_K), label: "K"), .init(id: UInt32(kVK_ANSI_L), label: "L"),
        .init(id: UInt32(kVK_ANSI_M), label: "M"), .init(id: UInt32(kVK_ANSI_N), label: "N"),
        .init(id: UInt32(kVK_ANSI_O), label: "O"), .init(id: UInt32(kVK_ANSI_P), label: "P"),
        .init(id: UInt32(kVK_ANSI_Q), label: "Q"), .init(id: UInt32(kVK_ANSI_R), label: "R"),
        .init(id: UInt32(kVK_ANSI_S), label: "S"), .init(id: UInt32(kVK_ANSI_T), label: "T"),
        .init(id: UInt32(kVK_ANSI_U), label: "U"), .init(id: UInt32(kVK_ANSI_V), label: "V"),
        .init(id: UInt32(kVK_ANSI_W), label: "W"), .init(id: UInt32(kVK_ANSI_X), label: "X"),
        .init(id: UInt32(kVK_ANSI_Y), label: "Y"), .init(id: UInt32(kVK_ANSI_Z), label: "Z"),
    ]

    static let numbers: [HotkeyKeyOption] = [
        .init(id: UInt32(kVK_ANSI_0), label: "0"), .init(id: UInt32(kVK_ANSI_1), label: "1"),
        .init(id: UInt32(kVK_ANSI_2), label: "2"), .init(id: UInt32(kVK_ANSI_3), label: "3"),
        .init(id: UInt32(kVK_ANSI_4), label: "4"), .init(id: UInt32(kVK_ANSI_5), label: "5"),
        .init(id: UInt32(kVK_ANSI_6), label: "6"), .init(id: UInt32(kVK_ANSI_7), label: "7"),
        .init(id: UInt32(kVK_ANSI_8), label: "8"), .init(id: UInt32(kVK_ANSI_9), label: "9"),
    ]

    static let functionKeys: [HotkeyKeyOption] = [
        .init(id: UInt32(kVK_F1), label: "F1"), .init(id: UInt32(kVK_F2), label: "F2"),
        .init(id: UInt32(kVK_F3), label: "F3"), .init(id: UInt32(kVK_F4), label: "F4"),
        .init(id: UInt32(kVK_F5), label: "F5"), .init(id: UInt32(kVK_F6), label: "F6"),
        .init(id: UInt32(kVK_F7), label: "F7"), .init(id: UInt32(kVK_F8), label: "F8"),
        .init(id: UInt32(kVK_F9), label: "F9"), .init(id: UInt32(kVK_F10), label: "F10"),
        .init(id: UInt32(kVK_F11), label: "F11"), .init(id: UInt32(kVK_F12), label: "F12"),
    ]

    static let specialKeys: [HotkeyKeyOption] = [
        .init(id: UInt32(kVK_Space), label: "Space"),
        .init(id: UInt32(kVK_Tab), label: "Tab"),
        .init(id: UInt32(kVK_Return), label: "Return"),
        .init(id: UInt32(kVK_Delete), label: "Delete"),
        .init(id: UInt32(kVK_ForwardDelete), label: "Forward Delete"),
        .init(id: UInt32(kVK_Escape), label: "Escape"),
        .init(id: UInt32(kVK_LeftArrow), label: "Left Arrow"),
        .init(id: UInt32(kVK_RightArrow), label: "Right Arrow"),
        .init(id: UInt32(kVK_UpArrow), label: "Up Arrow"),
        .init(id: UInt32(kVK_DownArrow), label: "Down Arrow"),
    ]

    static let groups: [(name: String, keys: [HotkeyKeyOption])] = [
        ("Letters", letters),
        ("Numbers", numbers),
        ("Function Keys", functionKeys),
        ("Special Keys", specialKeys),
    ]

    static let allKeysByCode: [UInt32: String] = Dictionary(
        uniqueKeysWithValues: (letters + numbers + functionKeys + specialKeys).map { ($0.id, $0.label) }
    )
}
