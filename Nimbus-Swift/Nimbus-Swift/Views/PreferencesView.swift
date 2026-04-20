//
//  PreferencesView.swift
//  Nimbus-Swift
//

import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @Environment(\.dismiss) var dismiss

    @State private var serverPath: String = ""
    @State private var catalogPath: String = ""
    @State private var backupPath: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Preferences")
                .font(.title)
                .fontWeight(.bold)
                .padding()

            Form {
                Section("Server Configuration") {
                    HStack {
                        TextField("Server Path", text: $serverPath)
                            .textFieldStyle(.roundedBorder)

                        Button("Choose...") {
                            selectFolder(for: .serverPath)
                        }
                    }

                    HStack {
                        TextField("Catalog Path", text: $catalogPath)
                            .textFieldStyle(.roundedBorder)

                        Button("Choose...") {
                            selectFolder(for: .catalogPath)
                        }
                    }

                    HStack {
                        TextField("Backup To Path", text: $backupPath)
                            .textFieldStyle(.roundedBorder)

                        Button("Choose...") {
                            selectFolder(for: .backupPath)
                        }
                    }
                }
            }
            .padding()

            // Footer buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    savePreferences()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 350)
        .onAppear {
            loadPreferences()
        }
    }

    private func loadPreferences() {
        serverPath = preferencesManager.preferences.serverPath
        catalogPath = preferencesManager.preferences.catalogPath
        backupPath = preferencesManager.preferences.backupPath
    }

    private func savePreferences() {
        preferencesManager.preferences.serverPath = serverPath
        preferencesManager.preferences.catalogPath = catalogPath
        preferencesManager.preferences.backupPath = backupPath
        preferencesManager.save()
        dismiss()
    }

    private enum FolderType {
        case serverPath, catalogPath, backupPath
    }

    private func selectFolder(for type: FolderType) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        switch type {
        case .serverPath:
            panel.message = "Select the server's folder:"
        case .catalogPath:
            panel.message = "Select the folder where your catalogs are kept:"
        case .backupPath:
            panel.message = "Select the folder to send backups to:"
        }

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let path = url.path

                switch type {
                case .serverPath:
                    serverPath = path.hasSuffix("/") ? path : path + "/"
                case .catalogPath:
                    catalogPath = path.hasSuffix("/") ? path : path + "/"
                case .backupPath:
                    backupPath = path.hasSuffix("/") ? path : path + "/"
                }
            }
        }
    }
}

#Preview {
    PreferencesView()
        .environmentObject(PreferencesManager())
}
