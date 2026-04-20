//
//  SnapshotDetailView.swift
//  Time Machine Manager
//
//  Created by RamosTech on 11/12/25.
//

import SwiftUI

struct SnapshotDetailView: View {
    let snapshot: Snapshot
    @ObservedObject var viewModel: SnapshotViewModel

    @State private var details: SnapshotDetails?
    @State private var isLoading = true
    @State private var showingDeleteConfirmation = false
    @State private var uniqueSize: String?
    @State private var isCalculatingSize = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    loadingView
                } else if let details = details {
                    detailsContent(details)
                } else {
                    errorView
                }
            }
            .padding()
        }
        .navigationTitle("Snapshot Details")
        .navigationSubtitle(snapshot.formattedDate)
        .onAppear {
            loadDetails()
        }
        .id(snapshot.id)
    }

    // MARK: - Content Views

    @ViewBuilder
    private func detailsContent(_ details: SnapshotDetails) -> some View {
        // Snapshot Information
        DetailSection(title: "Snapshot Information", icon: "clock.arrow.circlepath") {
            DetailRow(label: "Name", value: details.snapshot.fullName)
            DetailRow(label: "Created", value: details.snapshot.formattedDate)
            DetailRow(label: "Age", value: details.snapshot.age + " old")
            DetailRow(label: "Location", value: "/ (Root Volume)")
        }

        // Backup Destination
        DetailSection(title: "Backup Destination", icon: "externaldrive") {
            if !details.destination.name.isEmpty {
                DetailRow(label: "Name", value: details.destination.name)
                DetailRow(label: "Type", value: details.destination.kindDescription)
                DetailRow(label: "Device ID", value: details.destination.id.isEmpty ? "Not available" : details.destination.id)
                if let mountPoint = details.destination.mountPoint, !mountPoint.isEmpty {
                    DetailRow(label: "Mount Point", value: mountPoint)
                } else {
                    DetailRow(label: "Mount Point", value: "Not mounted")
                }
            } else {
                DetailRow(label: "Status", value: "Not configured")
            }
            DetailRow(label: "Latest Backup", value: details.latestBackup)
        }

        // System Information
        DetailSection(title: "System Information", icon: "internaldrive") {
            DetailRow(label: "Total Space", value: details.diskSpace.total)
            DetailRow(label: "Used Space", value: details.diskSpace.used)
            DetailRow(label: "Available Space", value: details.diskSpace.available)
            DetailRow(label: "Usage", value: details.diskSpace.percentUsed + " full")
        }

        // APFS Information
        if !details.apfsInfo.isEmpty && details.apfsInfo != "Not available" {
            DetailSection(title: "APFS Information", icon: "doc.text") {
                Text(details.apfsInfo)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
            }
        }

        // Unique Size Section
        DetailSection(title: "Storage Analysis", icon: "chart.pie") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unique Size")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let size = uniqueSize {
                        Text(size)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    } else {
                        Text("Not calculated")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: calculateUniqueSize) {
                    if isCalculatingSize {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Label("Calculate", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isCalculatingSize)
            }
        }

        // Commands Section
        DetailSection(title: "Terminal Commands", icon: "terminal") {
            VStack(alignment: .leading, spacing: 12) {
                // Delete command
                VStack(alignment: .leading, spacing: 4) {
                    Text("Delete this snapshot:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("sudo tmutil deletelocalsnapshots \(details.snapshot.datePart)")
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)

                        Button(action: {
                            copyToClipboard("sudo tmutil deletelocalsnapshots \(details.snapshot.datePart)")
                        }) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Text("⚠️ Copy the command above, paste it in Terminal, and press Enter. You'll need to enter your password.")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.top, 4)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading details...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Failed to load details")
                .font(.headline)
            Button("Retry") {
                loadDetails()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Data Loading

    private func loadDetails() {
        isLoading = true
        details = nil // Reset details
        Task {
            // Fetch details in background
            let loadedDetails = await fetchSnapshotDetails(snapshot)

            await MainActor.run {
                self.details = loadedDetails
                self.isLoading = false
            }
        }
    }

    nonisolated private func fetchSnapshotDetails(_ snapshot: Snapshot) async -> SnapshotDetails {
        return await TimeMachineManager.shared.getSnapshotDetails(snapshot)
    }

    private func calculateUniqueSize() {
        isCalculatingSize = true
        Task {
            let size = await fetchUniqueSize(snapshot)
            await MainActor.run {
                uniqueSize = size
                isCalculatingSize = false
            }
        }
    }

    nonisolated private func fetchUniqueSize(_ snapshot: Snapshot) async -> String {
        return await TimeMachineManager.shared.getUniqueSize(for: snapshot)
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Supporting Views

struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }

            VStack(spacing: 8) {
                content
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    let snapshot = Snapshot(fullName: "com.apple.TimeMachine.2024-01-15-120000",
                          date: Date(),
                          datePart: "2024-01-15-120000")
    SnapshotDetailView(snapshot: snapshot, viewModel: SnapshotViewModel())
}
