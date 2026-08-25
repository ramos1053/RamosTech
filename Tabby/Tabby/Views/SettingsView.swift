// SettingsView.swift
// Tabby
//
// Settings screen with toggles to install/uninstall each browser extension,
// and preferences for startup, hotkey, and appearance.

import SwiftUI
import ServiceManagement
import Carbon

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var launchAtLogin = false
    @State private var isRecordingHotkey = false
    var onOpenHelp: (() -> Void)?

    var body: some View {
        Form {
            // Browser Extensions
            Section("Browser Extensions") {
                Toggle(isOn: $viewModel.chromeInstalled) {
                    extensionRow(name: "Google Chrome", icon: "globe", color: .red)
                }
                .toggleStyle(.switch)

                Toggle(isOn: $viewModel.edgeInstalled) {
                    extensionRow(name: "Microsoft Edge", icon: "globe", color: .blue)
                }
                .toggleStyle(.switch)

                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 12))
                    Button("Setup guide") {
                        onOpenHelp?()
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
                    Text("— Learn how to install browser extensions.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // Status
            if viewModel.isProcessing || !viewModel.statusMessage.isEmpty {
                Section("Status") {
                    if viewModel.isProcessing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Processing...")
                                .foregroundColor(.secondary)
                        }
                    }

                    if !viewModel.statusMessage.isEmpty {
                        HStack {
                            Image(systemName: viewModel.statusMessage.hasPrefix("Error")
                                  ? "exclamationmark.triangle.fill"
                                  : "checkmark.circle.fill")
                                .foregroundColor(viewModel.statusMessage.hasPrefix("Error")
                                                 ? .red : .green)
                            Text(viewModel.statusMessage)
                                .font(.system(size: 12))
                        }
                    }
                }
            }

            // General
            Section("Startup") {
                Toggle("Launch Tabby at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("[Tabby] Login item error: \(error)")
                            launchAtLogin = !newValue
                        }
                    }

                Text("Tabby will start in the menu bar when you log in.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Section("Hotkey") {
                HStack {
                    Text("Toggle Tabby Window")
                    Spacer()

                    if isRecordingHotkey {
                        Text("Press a key combo...")
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.2)))
                            .font(.system(size: 12, design: .monospaced))
                            .overlay(
                                HotkeyRecorderView { config in
                                    viewModel.hotkeyConfig = config
                                    isRecordingHotkey = false
                                } onCancel: {
                                    isRecordingHotkey = false
                                }
                                .frame(width: 1, height: 1)
                                .opacity(0)
                            )
                    } else {
                        Button {
                            isRecordingHotkey = true
                        } label: {
                            Text(viewModel.hotkeyConfig.displayString)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RoundedRectangle(cornerRadius: 5).fill(.quaternary))
                                .font(.system(size: 12, design: .monospaced))
                        }
                        .buttonStyle(.plain)
                        .help("Click to change hotkey")
                    }
                }

                Text("Click the hotkey to record a new one. Press Escape to cancel.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Section("Appearance") {
                Picker("Theme", selection: $viewModel.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text("Choose how Tabby looks. Automatic follows your system setting.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            viewModel.refreshState()
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - Helpers

    private func extensionRow(name: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32, height: 32)

            Text(name)
                .font(.system(size: 14, weight: .medium))
        }
    }

    // MARK: - Hotkey Recorder

    /// An invisible NSView that captures key events to record a new hotkey.
    struct HotkeyRecorderView: NSViewRepresentable {
        let onRecord: (HotkeyConfig) -> Void
        let onCancel: () -> Void

        func makeNSView(context: Context) -> HotkeyRecorderNSView {
            let view = HotkeyRecorderNSView()
            view.onRecord = onRecord
            view.onCancel = onCancel
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
            return view
        }

        func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {}

        class HotkeyRecorderNSView: NSView {
            var onRecord: ((HotkeyConfig) -> Void)?
            var onCancel: (() -> Void)?

            override var acceptsFirstResponder: Bool { true }

            override func keyDown(with event: NSEvent) {
                // Escape cancels
                if event.keyCode == 53 {
                    onCancel?()
                    return
                }

                // Require at least one modifier
                let flags = event.modifierFlags
                let hasCmd = flags.contains(.command)
                let hasShift = flags.contains(.shift)
                let hasOpt = flags.contains(.option)
                let hasCtrl = flags.contains(.control)

                guard hasCmd || hasOpt || hasCtrl else {
                    // Need at least Cmd, Opt, or Ctrl
                    return
                }

                let config = HotkeyConfig(
                    keyCode: UInt32(event.keyCode),
                    useCommand: hasCmd,
                    useShift: hasShift,
                    useOption: hasOpt,
                    useControl: hasCtrl
                )
                onRecord?(config)
            }
        }
    }

}
