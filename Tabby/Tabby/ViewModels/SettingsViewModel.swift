// SettingsViewModel.swift
// Tabby
//
// View model for the Settings screen. Manages the install/uninstall state
// of each browser extension and coordinates with ExtensionInstaller.

import Foundation
import Combine
import Carbon

// MARK: - HotkeyModifiers

/// Represents modifier keys for a custom hotkey
struct HotkeyConfig: Codable, Equatable {
    var keyCode: UInt32
    var useCommand: Bool
    var useShift: Bool
    var useOption: Bool
    var useControl: Bool

    /// Display string like "Cmd + Shift + T"
    var displayString: String {
        var parts: [String] = []
        if useControl { parts.append("Ctrl") }
        if useOption  { parts.append("Opt") }
        if useShift   { parts.append("Shift") }
        if useCommand { parts.append("Cmd") }
        parts.append(keyCodeName)
        return parts.joined(separator: " + ")
    }

    /// Carbon modifier mask
    var carbonModifiers: UInt32 {
        var mods: UInt32 = 0
        if useCommand { mods |= UInt32(cmdKey) }
        if useShift   { mods |= UInt32(shiftKey) }
        if useOption  { mods |= UInt32(optionKey) }
        if useControl { mods |= UInt32(controlKey) }
        return mods
    }

    /// Human-readable key name from Carbon keyCode
    var keyCodeName: String {
        let keyNames: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 50: "`",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9",
            109: "F10", 111: "F12", 103: "F11", 105: "F13", 107: "F14",
            113: "F15", 106: "F16", 118: "F4", 120: "F2", 122: "F1",
            123: "Left", 124: "Right", 125: "Down", 126: "Up",
            36: "Return", 48: "Tab", 51: "Delete", 53: "Escape",
            76: "Enter", 115: "Home", 119: "End", 116: "PageUp", 121: "PageDown"
        ]
        return keyNames[keyCode] ?? "Key\(keyCode)"
    }

    /// Default hotkey: Cmd+Shift+T
    static let `default` = HotkeyConfig(
        keyCode: UInt32(kVK_ANSI_T),
        useCommand: true,
        useShift: true,
        useOption: false,
        useControl: false
    )
}

// MARK: - AppearanceMode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case automatic = "automatic"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .light:     return "Light"
        case .dark:      return "Dark"
        }
    }
}

// MARK: - SettingsViewModel

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    /// Whether the Chrome extension is installed
    @Published var chromeInstalled: Bool = false {
        didSet { handleToggle(browser: .chrome, installed: chromeInstalled) }
    }

    /// Whether the Edge extension is installed
    @Published var edgeInstalled: Bool = false {
        didSet { handleToggle(browser: .edge, installed: edgeInstalled) }
    }

    /// Status message for user feedback
    @Published var statusMessage: String = ""

    /// Whether an operation is in progress
    @Published var isProcessing: Bool = false

    /// Custom hotkey configuration
    @Published var hotkeyConfig: HotkeyConfig = .default {
        didSet {
            saveHotkeyConfig()
            onHotkeyChanged?(hotkeyConfig)
        }
    }

    /// Appearance mode
    @Published var appearanceMode: AppearanceMode = .automatic {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
            onAppearanceChanged?(appearanceMode)
        }
    }

    /// Callback when hotkey changes so AppDelegate can re-register
    var onHotkeyChanged: ((HotkeyConfig) -> Void)?

    /// Callback when appearance changes so AppDelegate can apply
    var onAppearanceChanged: ((AppearanceMode) -> Void)?

    // MARK: - Private

    private var isUpdating = false

    // MARK: - Init

    init() {
        loadHotkeyConfig()
        loadAppearanceMode()
        refreshState()
    }

    // MARK: - Public API

    /// Refresh the installation state of all extensions.
    func refreshState() {
        isUpdating = true
        chromeInstalled = ExtensionInstaller.isInstalled(for: .chrome)
        edgeInstalled = ExtensionInstaller.isInstalled(for: .edge)
        isUpdating = false
    }

    // MARK: - Private

    private func handleToggle(browser: Browser, installed: Bool) {
        // Skip if we're just refreshing state programmatically
        guard !isUpdating else { return }

        isProcessing = true
        statusMessage = ""

        Task { [weak self] in
            do {
                if installed {
                    try await Task.detached {
                        try ExtensionInstaller.install(for: browser)
                    }.value
                    self?.statusMessage = "\(browser.displayName) extension installed successfully."
                } else {
                    await Task.detached {
                        ExtensionInstaller.uninstall(for: browser)
                    }.value
                    self?.statusMessage = "\(browser.displayName) extension uninstalled."
                }
                self?.isProcessing = false
            } catch {
                self?.statusMessage = "Error: \(error.localizedDescription)"
                self?.isProcessing = false
                // Revert the toggle
                self?.isUpdating = true
                switch browser {
                case .chrome:  self?.chromeInstalled = !installed
                case .edge:    self?.edgeInstalled = !installed
                }
                self?.isUpdating = false
            }
        }
    }

    // MARK: - Hotkey Persistence

    private func saveHotkeyConfig() {
        guard !isUpdating else { return }
        if let data = try? JSONEncoder().encode(hotkeyConfig) {
            UserDefaults.standard.set(data, forKey: "hotkeyConfig")
        }
    }

    private func loadHotkeyConfig() {
        isUpdating = true
        if let data = UserDefaults.standard.data(forKey: "hotkeyConfig"),
           let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            hotkeyConfig = config
        }
        isUpdating = false
    }

    private func loadAppearanceMode() {
        isUpdating = true
        if let raw = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: raw) {
            appearanceMode = mode
        }
        isUpdating = false
    }
}
