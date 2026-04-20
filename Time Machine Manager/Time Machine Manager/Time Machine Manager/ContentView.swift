//
//  ContentView.swift
//  Time Machine Manager
//
//  Created by RamosTech on 11/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SnapshotViewModel()
    @State private var selectedSnapshot: Snapshot?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingAdvancedTools = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                // Header Section
                headerView

                Divider()

                // Snapshot List
                if viewModel.isLoading && viewModel.snapshots.isEmpty {
                    loadingView
                } else if viewModel.snapshots.isEmpty {
                    emptyStateView
                } else {
                    snapshotListView
                }
            }
            .navigationTitle("Time Machine Manager")
            .navigationSplitViewColumnWidth(355) // 2.875 inches
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { viewModel.loadData() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAdvancedTools = true }) {
                        Label("Advanced Tools", systemImage: "gearshape.2")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        } detail: {
            ZStack {
                // Watermark background - fills the space
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.03)

                // Content
                if let snapshot = selectedSnapshot {
                    SnapshotDetailView(snapshot: snapshot, viewModel: viewModel)
                } else {
                    Text("Select a snapshot to view details")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            viewModel.loadData()
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .alert("Success", isPresented: $viewModel.showingSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.successMessage ?? "Operation completed successfully")
        }
        .sheet(isPresented: $showingAdvancedTools) {
            AdvancedToolsView(viewModel: viewModel)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(viewModel.tmStatus.rawValue)
                            .font(.headline)
                    }
                }

                Spacer()
            }

            Divider()

            VStack(spacing: 8) {
                InfoRow(label: "Snapshots", value: "\(viewModel.snapshotCount) (\(viewModel.estimatedSize))")

                // Destination Info - always show for debugging
                VStack(alignment: .leading, spacing: 4) {
                    InfoRow(label: "Destination",
                           value: viewModel.destinationInfo.name.isEmpty ? "Not configured" : viewModel.destinationInfo.name)
                    if !viewModel.destinationInfo.kind.isEmpty {
                        InfoRow(label: "Type", value: viewModel.destinationInfo.kindDescription)
                    }
                    if !viewModel.destinationInfo.id.isEmpty {
                        InfoRow(label: "ID", value: String(viewModel.destinationInfo.id.prefix(8)) + "...")
                    }
                }

                InfoRow(label: "Disk Space", value: viewModel.diskSpace.description)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var statusColor: Color {
        switch viewModel.tmStatus {
        case .running:
            return .blue
        case .enabled:
            return .green
        case .disabled:
            return .red
        }
    }

    // MARK: - Snapshot List View

    private var snapshotListView: some View {
        List(selection: $selectedSnapshot) {
            ForEach(viewModel.snapshots) { snapshot in
                SnapshotRow(snapshot: snapshot)
                    .tag(snapshot)
                    .contextMenu {
                        Button("Show Details") {
                            selectedSnapshot = snapshot
                        }
                        Divider()
                        Button("Copy Delete Command") {
                            copyToClipboard("sudo tmutil deletelocalsnapshots \(snapshot.datePart)")
                        }
                    }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Empty/Loading States

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Snapshots Found")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Time Machine snapshots will appear here")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading snapshots...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Functions

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

struct SnapshotRow: View {
    let snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.formattedDate)
                .font(.system(.body, design: .monospaced))
            Text(snapshot.age + " old")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
