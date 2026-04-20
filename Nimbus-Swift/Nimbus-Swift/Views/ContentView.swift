//
//  ContentView.swift
//  Nimbus-Swift
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @StateObject private var serverViewModel = ServerViewModel()
    @State private var showingPreferences = false
    @State private var commandInput = ""

    var body: some View {
        VStack(spacing: 0) {
            // Compact Header
            CompactHeaderView()

            // Main content - NO ScrollView
            VStack(spacing: 12) {
                // Server Monitoring with graphs
                ServerMonitoringView(viewModel: serverViewModel)

                HStack(spacing: 12) {
                    // Server Controls
                    CompactServerControlsSection(viewModel: serverViewModel, preferencesManager: preferencesManager)

                    // Backup & Maintenance
                    CompactActionsSection(viewModel: serverViewModel, preferencesManager: preferencesManager)
                }

                // Command Execution - Compact
                CompactCommandSection(viewModel: serverViewModel, commandInput: $commandInput)
            }
            .padding(12)

            // Compact Footer
            CompactFooterView(showingPreferences: $showingPreferences)
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
                .environmentObject(preferencesManager)
        }
        .alert(serverViewModel.alertTitle, isPresented: $serverViewModel.showAlert) {
            Button("OK") {
                serverViewModel.showAlert = false
            }
        } message: {
            Text(serverViewModel.alertMessage)
        }
        .onAppear {
            serverViewModel.setCatalogPath(preferencesManager.preferences.catalogPath)
            serverViewModel.startMonitoring()
        }
        .onDisappear {
            serverViewModel.stopMonitoring()
        }
        .onChange(of: preferencesManager.preferences.catalogPath) { oldPath, newPath in
            serverViewModel.setCatalogPath(newPath)
        }
    }
}

// MARK: - Compact Header
struct CompactHeaderView: View {
    var body: some View {
        ZStack {
            Color.blue.opacity(0.3)

            HStack {
                Image(systemName: "cloud.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 30)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nimbus")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    Text("Cumulus Server Management")
                        .font(.caption)
                        .foregroundColor(.black.opacity(0.9))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 70)
    }
}

// MARK: - Compact Server Controls
struct CompactServerControlsSection: View {
    @ObservedObject var viewModel: ServerViewModel
    @ObservedObject var preferencesManager: PreferencesManager

    var body: some View {
        GroupBox(label: Label("Server", systemImage: "server.rack").font(.caption)) {
            VStack(spacing: 6) {
                Button(action: {
                    Task {
                        await viewModel.startServer(serverPath: preferencesManager.preferences.serverPath)
                    }
                }) {
                    Label("Start", systemImage: "play.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: {
                    Task {
                        await viewModel.stopServer(serverPath: preferencesManager.preferences.serverPath)
                    }
                }) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Compact Actions Section
struct CompactActionsSection: View {
    @ObservedObject var viewModel: ServerViewModel
    @ObservedObject var preferencesManager: PreferencesManager

    var body: some View {
        GroupBox(label: Label("Actions", systemImage: "gearshape.2").font(.caption)) {
            VStack(spacing: 6) {
                Button(action: {
                    Task {
                        await viewModel.backupCatalogs(
                            catalogPath: preferencesManager.preferences.catalogPath,
                            backupPath: preferencesManager.preferences.backupPath
                        )
                    }
                }) {
                    Label("Backup", systemImage: "arrow.down.doc")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)

                Menu {
                    Button(action: {
                        viewModel.viewSystemLog()
                    }) {
                        Label("View System Log", systemImage: "doc.text")
                    }

                    Button(action: {
                        Task {
                            await viewModel.cleanupSystemLogs()
                        }
                    }) {
                        Label("Cleanup Logs", systemImage: "trash")
                    }
                } label: {
                    Label("Maintenance", systemImage: "wrench")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Compact Command Section
struct CompactCommandSection: View {
    @ObservedObject var viewModel: ServerViewModel
    @Binding var commandInput: String

    var body: some View {
        GroupBox(label: Label("Console Command", systemImage: "terminal").font(.caption)) {
            VStack(spacing: 6) {
                HStack {
                    TextField("Enter command...", text: $commandInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .onSubmit {
                            executeCommand()
                        }

                    Button("Run") {
                        executeCommand()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if !viewModel.lastMessage.isEmpty {
                    ScrollView {
                        Text(viewModel.lastMessage)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color(nsColor: .textBackgroundColor))
                            .cornerRadius(4)
                    }
                    .frame(height: 60)
                }
            }
            .padding(.top, 4)
        }
    }

    private func executeCommand() {
        guard !commandInput.isEmpty else { return }
        Task {
            await viewModel.executeCommand(commandInput)
        }
    }
}

// MARK: - Compact Footer
struct CompactFooterView: View {
    @Binding var showingPreferences: Bool

    var body: some View {
        HStack {
            Button("Preferences") {
                showingPreferences = true
            }
            .controlSize(.small)

            Spacer()

            Text("Nimbus 3.0 - Freeware")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    ContentView()
        .environmentObject(PreferencesManager())
        .frame(width: 650, height: 550)
}
