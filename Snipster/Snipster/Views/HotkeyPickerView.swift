//
//  HotkeyPickerView.swift
//  Snipster
//

import SwiftUI
import Carbon

/// Lets the user assemble a global hotkey from explicit controls (modifier
/// toggles + a key picker) instead of capturing a live keypress. Presented
/// as a popover from SettingsView.
struct HotkeyPickerView: View {
    @Binding var isPresented: Bool
    @ObservedObject var hotkeyManager: HotkeyManager

    @State private var useCommand = true
    @State private var useOption = false
    @State private var useControl = false
    @State private var useShift = true
    @State private var selectedKeyCode: UInt32 = UInt32(kVK_ANSI_S)

    private var modifiers: UInt32 {
        var flags: UInt32 = 0
        if useControl { flags |= UInt32(controlKey) }
        if useOption { flags |= UInt32(optionKey) }
        if useShift { flags |= UInt32(shiftKey) }
        if useCommand { flags |= UInt32(cmdKey) }
        return flags
    }

    private var conflict: String? {
        hotkeyManager.checkForConflicts(keyCode: selectedKeyCode, modifiers: modifiers)
    }

    private var previewText: String {
        var parts: [String] = []
        if useControl { parts.append("⌃") }
        if useOption { parts.append("⌥") }
        if useShift { parts.append("⇧") }
        if useCommand { parts.append("⌘") }
        parts.append(HotkeyKeyCatalog.allKeysByCode[selectedKeyCode] ?? "?")
        return parts.joined()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose Hotkey")
                .font(.headline)

            HStack(spacing: 6) {
                modifierToggle("⌃", isOn: $useControl)
                modifierToggle("⌥", isOn: $useOption)
                modifierToggle("⇧", isOn: $useShift)
                modifierToggle("⌘", isOn: $useCommand)

                Spacer()

                Text(previewText)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
            }

            Picker("Key", selection: $selectedKeyCode) {
                ForEach(HotkeyKeyCatalog.groups, id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.keys) { key in
                            Text(key.label).tag(key.id)
                        }
                    }
                }
            }
            .pickerStyle(.menu)

            if let conflict {
                Label(conflict, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            HStack {
                Button("Reset to Default") {
                    hotkeyManager.resetToDefault()
                    isPresented = false
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }

                Button("Set Hotkey") {
                    try? hotkeyManager.updateHotkey(keyCode: selectedKeyCode, modifiers: modifiers)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(conflict != nil)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            useControl = (hotkeyManager.currentModifiers & UInt32(controlKey)) != 0
            useOption = (hotkeyManager.currentModifiers & UInt32(optionKey)) != 0
            useShift = (hotkeyManager.currentModifiers & UInt32(shiftKey)) != 0
            useCommand = (hotkeyManager.currentModifiers & UInt32(cmdKey)) != 0
            selectedKeyCode = hotkeyManager.currentKeyCode
        }
    }

    private func modifierToggle(_ symbol: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(symbol).font(.system(size: 14, weight: .medium))
        }
        .toggleStyle(.button)
        .controlSize(.small)
    }
}
