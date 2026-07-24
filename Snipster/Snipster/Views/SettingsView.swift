//
//  SettingsView.swift
//  Snipster
//
//  Created by RamosTech on 12/16/25.
//

import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var viewModel: SnippetViewModel
    @StateObject private var textExpansion = TextExpansionMonitor.shared
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var copyPathService = CopyPathService.shared
    @StateObject private var clipboardHistory = ClipboardHistoryService.shared
    @ObservedObject private var appSettings = AppSettings.shared
    @State private var launchAtLogin: Bool = false
    @State private var showHotkeyPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                HStack(alignment: .top, spacing: 16) {
                    // Left Column
                    VStack(alignment: .leading, spacing: 12) {
                        // Global Hotkey
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Quick Access Hotkey", systemImage: "command.square")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 6) {
                                    Toggle(isOn: $hotkeyManager.isEnabled) {
                                        Text("Enable Global Hotkey")
                                            .font(.subheadline)
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: .green))

                                    HStack {
                                        Text("Current:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(hotkeyManager.getHotkeyDescription())
                                            .font(.system(.caption, design: .monospaced))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor.opacity(0.1))
                                            .cornerRadius(4)
                                        Spacer()
                                        Button("Choose Hotkey…") {
                                            showHotkeyPicker = true
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .popover(isPresented: $showHotkeyPicker) {
                                            HotkeyPickerView(isPresented: $showHotkeyPicker, hotkeyManager: hotkeyManager)
                                        }
                                    }
                                }
                            }
                            .padding(10)
                        }

                        // Text Expansion
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Text Expansion", systemImage: "keyboard")
                                    .font(.headline)

                                HStack(spacing: 12) {
                                    Image(systemName: textExpansion.hasAccessibilityPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(textExpansion.hasAccessibilityPermission ? .green : .red)
                                        .font(.title3)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(textExpansion.hasAccessibilityPermission ? "Enabled" : "Disabled")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(textExpansion.hasAccessibilityPermission ?
                                             "Ready to use" :
                                             "Grant permission")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if textExpansion.hasAccessibilityPermission {
                                        Button(action: { textExpansion.restartMonitoring() }) {
                                            Image(systemName: "arrow.clockwise")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .help("Refresh monitoring")
                                    } else {
                                        Button("Enable") {
                                            textExpansion.requestAccessibilityPermission()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                    }
                                }
                            }
                            .padding(10)
                        }

                        // Finder Integration
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Finder Integration", systemImage: "folder.badge.gearshape")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 6) {
                                    Toggle(isOn: $copyPathService.isEnabled) {
                                        Text("Enable \"Copy Path\" in Finder")
                                            .font(.subheadline)
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: .green))

                                    Text("Right-click a file in Finder and choose Services > Copy Path to copy its path to the clipboard. macOS always shows this menu item while Snipster is running; turning it off here makes Finder show an alert instead of copying the path.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(10)
                        }

                        // Clipboard History
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Clipboard History", systemImage: "doc.on.clipboard")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 6) {
                                    Toggle(isOn: $clipboardHistory.isEnabled) {
                                        Text("Remember recent clipboard copies")
                                            .font(.subheadline)
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: .green))

                                    HStack {
                                        Text("Keep last:")
                                            .font(.subheadline)
                                        Spacer()
                                        Picker("", selection: $clipboardHistory.historyLimit) {
                                            Text("10").tag(10)
                                            Text("30").tag(30)
                                            Text("50").tag(50)
                                            Text("100").tag(100)
                                        }
                                        .pickerStyle(.segmented)
                                        .frame(width: 220)
                                    }

                                    HStack {
                                        Text("Auto-clear:")
                                            .font(.subheadline)
                                        Spacer()
                                        Picker("", selection: $clipboardHistory.wipeInterval) {
                                            ForEach(ClipboardHistoryService.WipeInterval.allCases) { interval in
                                                Text(interval.label).tag(interval)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 140)
                                    }

                                    Button("Clear History Now") {
                                        clipboardHistory.clearNow()
                                    }
                                    .disabled(clipboardHistory.entries.isEmpty)

                                    Text("History is kept in memory only — it's never written to disk, and clears automatically when Snipster quits in addition to whatever auto-clear schedule you choose above. Right-click any entry in the quick-access search window and choose \"Save as Snippet\" to keep it permanently.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(10)
                        }

                        // Display Settings
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Display", systemImage: "eye")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Preview Lines:")
                                            .font(.subheadline)
                                        Spacer()
                                        Picker("", selection: $appSettings.previewLines) {
                                            Text("None").tag(0)
                                            Text("1").tag(1)
                                            Text("2").tag(2)
                                        }
                                        .pickerStyle(.segmented)
                                        .frame(width: 140)
                                    }
                                }
                            }
                            .padding(10)
                        }

                        // App Preferences
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Preferences", systemImage: "switch.2")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 6) {
                                    Toggle(isOn: $launchAtLogin) {
                                        Text("Launch at Login")
                                            .font(.subheadline)
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: .green))
                                    .onChange(of: launchAtLogin) { oldValue, newValue in
                                        setLaunchAtLogin(newValue)
                                    }
                                }
                            }
                            .padding(10)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Right Column
                    VStack(alignment: .leading, spacing: 12) {
                        // Backup & Restore
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Backup & Restore", systemImage: "externaldrive")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 12) {
                                        Button(action: { exportSnippets() }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "square.and.arrow.up")
                                                Text("Export")
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)

                                        Button(action: { importSnippets() }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "square.and.arrow.down")
                                                Text("Import")
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }

                                    Text("\(viewModel.snippetStore.snippets.count) total snippets")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(10)
                        }

                        // Storage Location
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Storage", systemImage: "folder")
                                    .font(.headline)

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(viewModel.storageLocation.rawValue)
                                            .font(.subheadline)
                                        Spacer()
                                        Button("Change") {
                                            WindowHelper.openStorageLocationWindow(viewModel: viewModel)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }

                                    if let path = viewModel.resolvedStoragePath {
                                        Text(path.path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(10)
                        }

                        // Tag Management
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Tags", systemImage: "tag.fill")
                                    .font(.headline)

                                InlineTagManagement()
                            }
                            .padding(10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
        }
        .frame(minWidth: 700, idealWidth: 800, maxWidth: 1000, minHeight: 500, idealHeight: 600)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled {
                    try? SMAppService.mainApp.unregister()
                }
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Failed to set launch at login
        }
    }

    private func exportSnippets() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Snipster-Export-\(Date().ISO8601Format()).json"
        panel.message = "Export all snippets to JSON file"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            Task {
                do {
                    try await viewModel.snippetStore.exportSnippets(to: url, tags: viewModel.tagStore.tags)
                } catch {
                    // Export failed
                }
            }
        }
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Import snippets from JSON file"

        panel.begin { response in
            guard response == .OK, let url = panel.urls.first else { return }

            Task {
                do {
                    let result = try await viewModel.snippetStore.importSnippets(from: url, mode: .merge)
                    await viewModel.tagStore.mergeTags(result.importedTags)
                } catch {
                    // Import failed
                }
            }
        }
    }
}

struct InlineTagManagement: View {
    @EnvironmentObject var tagStore: TagStore
    @EnvironmentObject var viewModel: SnippetViewModel

    @State private var tagToDelete: Tag?
    @State private var showingDeleteConfirmation = false

    var sortedTags: [Tag] {
        tagStore.tags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if sortedTags.isEmpty {
                Text("No tags yet. Create your first tag to organize snippets.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(sortedTags) { tag in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 12, height: 12)

                            Text(tag.name)
                                .font(.subheadline)

                            Spacer()

                            let snippetCount = viewModel.snippetStore.snippets.filter { $0.tagIDs.contains(tag.id) }.count
                            Text("\(snippetCount)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tag.color)
                                .cornerRadius(8)

                            Button(action: {
                                WindowHelper.openTagEditWindow(tag: tag) { updatedTag in
                                    Task {
                                        await tagStore.updateTag(updatedTag)
                                    }
                                }
                            }) {
                                Image(systemName: "pencil")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .controlSize(.small)

                            Button(action: {
                                tagToDelete = tag
                                showingDeleteConfirmation = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(tag.color.opacity(0.05))
                        .cornerRadius(6)
                    }
                }
                .frame(maxHeight: 200)
            }

            Button(action: {
                WindowHelper.openTagEditWindow(tag: nil) { newTag in
                    Task {
                        await tagStore.addTag(newTag)
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                    Text("Add Tag")
                }
                .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .alert("Delete Tag", isPresented: $showingDeleteConfirmation, presenting: tagToDelete) { tag in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await tagStore.deleteTag(tag)
                }
            }
        } message: { tag in
            let count = viewModel.snippetStore.snippets.filter { $0.tagIDs.contains(tag.id) }.count
            if count > 0 {
                Text("This tag is used by \(count) snippet\(count == 1 ? "" : "s"). Deleting it will remove the tag from all snippets.")
            } else {
                Text("Are you sure you want to delete this tag?")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SnippetViewModel())
}
