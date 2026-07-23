//
//  StorageLocationPicker.swift
//  Snipster
//
//  Created by RamosTech on 12/16/25.
//

import SwiftUI
import AppKit

struct StorageLocationPicker: View {
    @EnvironmentObject var viewModel: SnippetViewModel
    @State private var showingFolderError = false

    private func closeWindow() {
        if let window = NSApplication.shared.keyWindow {
            window.close()
        }
    }

    private func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose a folder to store your Snipster data — iCloud Drive, OneDrive, Google Drive, Dropbox, or any external volume all work, since this is just a regular folder."

        // Default to iCloud Drive's Documents folder if it exists, since
        // that's the most common reason someone reaches for a custom folder.
        if let iCloudDocuments = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents"),
           FileManager.default.fileExists(atPath: iCloudDocuments.path) {
            panel.directoryURL = iCloudDocuments
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard FileManager.default.isWritableFile(atPath: url.path) else {
            showingFolderError = true
            return
        }

        viewModel.changeStorageLocation(.custom, customPath: url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage Location")
                .font(.headline)

            Text("Choose where to save your snippets")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            Button(action: { viewModel.changeStorageLocation(.local) }) {
                storageRow(
                    icon: StorageLocation.local.icon,
                    title: StorageLocation.local.rawValue,
                    path: StorageLocation.local.defaultPath?.path,
                    unsetPlaceholder: nil,
                    isSelected: viewModel.storageLocation == .local
                )
            }
            .buttonStyle(.plain)

            Button(action: chooseCustomFolder) {
                storageRow(
                    icon: StorageLocation.custom.icon,
                    title: "Custom Folder…",
                    path: viewModel.storageLocation == .custom ? viewModel.customStoragePath?.path : nil,
                    unsetPlaceholder: "Not set",
                    isSelected: viewModel.storageLocation == .custom
                )
            }
            .buttonStyle(.plain)

            Text("A custom folder works for anything you can navigate to in the picker — iCloud Drive, OneDrive, Google Drive, Dropbox, or an external drive.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            HStack {
                Spacer()
                Button("Done") {
                    closeWindow()
                }
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 450, height: 400)
        .alert("Folder Not Writable", isPresented: $showingFolderError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Snipster doesn't have permission to write to that folder. Choose a different one.")
        }
    }

    @ViewBuilder
    private func storageRow(icon: String, title: String, path: String?, unsetPlaceholder: String?, isSelected: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.body)

                if let path {
                    Text(path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if let unsetPlaceholder {
                    Text(unsetPlaceholder)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }
}

#Preview {
    StorageLocationPicker()
        .environmentObject(SnippetViewModel())
}
