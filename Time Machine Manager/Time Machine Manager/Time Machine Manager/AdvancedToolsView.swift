//
//  AdvancedToolsView.swift
//  Time Machine Manager
//
//  Created by Alan Ramos on 11/13/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct AdvancedToolsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SnapshotViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Advanced Tools")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Tab Selection
            Picker("Tool", selection: $selectedTab) {
                Text("Snapshot Management").tag(0)
                Text("Exclusions").tag(1)
                Text("Backup Analysis").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab Content
            TabView(selection: $selectedTab) {
                SnapshotManagementView(viewModel: viewModel)
                    .tag(0)

                ExclusionManagementView(viewModel: viewModel)
                    .tag(1)

                BackupAnalysisView(viewModel: viewModel)
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 800, height: 600)
    }
}

// MARK: - Snapshot Management Tab

struct SnapshotManagementView: View {
    @ObservedObject var viewModel: SnapshotViewModel
    @State private var purgeAmountGB: Int = 5
    @State private var urgencyLevel: Int = 2
    @State private var showingThinResult = false
    @State private var thinResultMessage = ""
    @State private var calculatingSize = false
    @State private var uniqueSize = "Calculating..."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Thin Snapshots Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.accentColor)
                        Text("Thin Local Snapshots")
                            .font(.headline)
                    }

                    Text("Reclaim disk space by thinning local APFS snapshots. Time Machine will delete the oldest snapshots to free up the requested amount.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 16) {
                        // Amount to reclaim
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Space to Reclaim (GB)")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            HStack {
                                Slider(value: Binding(
                                    get: { Double(purgeAmountGB) },
                                    set: { purgeAmountGB = Int($0) }
                                ), in: 1...50, step: 1)

                                Text("\(purgeAmountGB) GB")
                                    .font(.subheadline)
                                    .frame(width: 60, alignment: .trailing)
                                    .foregroundColor(.primary)
                            }
                        }

                        // Urgency level
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Urgency Level")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Picker("Urgency", selection: $urgencyLevel) {
                                Text("Low (Completes backups first)").tag(1)
                                Text("Medium").tag(2)
                                Text("High").tag(3)
                                Text("Very High (Stops backups)").tag(4)
                            }
                            .pickerStyle(.radioGroup)
                        }

                        Button(action: executeThin) {
                            Label("Generate Thin Command", systemImage: "terminal")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }

                // Unique Size Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.accentColor)
                        Text("Snapshot Size Analysis")
                            .font(.headline)
                    }

                    Text("Calculate the unique storage space used by local snapshots (excluding shared/hardlinked data).")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Unique Size:")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if calculatingSize {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 20, height: 20)
                            }

                            Text(uniqueSize)
                                .font(.subheadline)
                                .foregroundColor(.primary)

                            Spacer()

                            Button(action: calculateSize) {
                                Label("Calculate", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(calculatingSize)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }

                Spacer()
            }
            .padding()
        }
        .alert("Thin Snapshots Command", isPresented: $showingThinResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(thinResultMessage)
        }
    }

    private func executeThin() {
        let result = TimeMachineManager.shared.thinLocalSnapshots(purgeAmountGB: purgeAmountGB, urgency: urgencyLevel)

        switch result {
        case .success:
            thinResultMessage = "Command executed successfully"
        case .failure(let error):
            thinResultMessage = error.localizedDescription
        }

        showingThinResult = true
    }

    private func calculateSize() {
        calculatingSize = true
        Task {
            let size = await fetchUniqueSize()
            await MainActor.run {
                uniqueSize = size
                calculatingSize = false
            }
        }
    }

    nonisolated private func fetchUniqueSize() async -> String {
        // Use a dummy snapshot for the calculation - uniquesize works on volume level
        let dummySnapshot = Snapshot(fullName: "", date: Date(), datePart: "")
        return await TimeMachineManager.shared.getUniqueSize(for: dummySnapshot)
    }
}

// MARK: - Exclusion Management Tab

struct ExclusionManagementView: View {
    @ObservedObject var viewModel: SnapshotViewModel
    @State private var excludedItems: [ExcludedItem] = []
    @State private var checkPath = ""
    @State private var exclusionStatus = ""
    @State private var showingFilePicker = false
    @State private var selectedExclusionType: ExclusionType = .fixed
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            // Check Exclusion Status Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.accentColor)
                    Text("Check Exclusion Status")
                        .font(.headline)
                }

                HStack {
                    TextField("Enter path to check...", text: $checkPath)
                        .textFieldStyle(.roundedBorder)

                    Button(action: checkExclusion) {
                        Label("Check", systemImage: "arrow.right.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(checkPath.isEmpty)
                }

                if !exclusionStatus.isEmpty {
                    Text(exclusionStatus)
                        .font(.caption)
                        .foregroundColor(exclusionStatus.contains("Excluded") ? .orange : .green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                }
            }
            .padding()
            .background(Color(NSColor.textBackgroundColor))

            Divider()

            // Excluded Items List
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Currently Excluded Paths")
                        .font(.headline)

                    Spacer()

                    Button(action: loadExcludedItems) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                .padding(.top)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if excludedItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No excluded paths configured")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(excludedItems) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(item.path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(item.type.rawValue)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                            .padding(.vertical, 4)
                            .contextMenu {
                                Button("Copy Path") {
                                    copyToClipboard(item.path)
                                }
                                Divider()
                                Button("Copy Remove Command") {
                                    let flag = item.type == .sticky ? "" : "-p"
                                    copyToClipboard("tmutil removeexclusion \(flag) \"\(item.path)\"")
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadExcludedItems()
        }
    }

    private func checkExclusion() {
        let status = TimeMachineManager.shared.checkExclusionStatus(path: checkPath)
        exclusionStatus = status.description
    }

    private func loadExcludedItems() {
        isLoading = true
        Task {
            let items = await fetchExcludedItems()
            await MainActor.run {
                excludedItems = items
                isLoading = false
            }
        }
    }

    nonisolated private func fetchExcludedItems() async -> [ExcludedItem] {
        return await TimeMachineManager.shared.listExcludedItems()
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// MARK: - Backup Analysis Tab

struct BackupAnalysisView: View {
    @ObservedObject var viewModel: SnapshotViewModel
    @State private var comparisonResult: ComparisonResult?
    @State private var driftAnalysis: DriftAnalysis?
    @State private var integrityResult: IntegrityCheckResult?
    @State private var isComparingBackup = false
    @State private var isCalculatingDrift = false
    @State private var isVerifyingIntegrity = false
    @State private var allBackups: [BackupInfo] = []
    @State private var isLoadingBackups = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Compare to Latest Backup
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundColor(.accentColor)
                        Text("Compare to Latest Backup")
                            .font(.headline)
                    }

                    Text("Compare your current system state to the most recent backup to see what has changed.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Button(action: compareToBackup) {
                            if isComparingBackup {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 20, height: 20)
                            } else {
                                Label("Run Comparison", systemImage: "play.circle")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isComparingBackup)

                        if let result = comparisonResult, !result.differences.isEmpty {
                            Button(action: { exportComparisonToCSV(result) }) {
                                Label("Export to CSV", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    if let result = comparisonResult {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: result.identical ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(result.identical ? .green : .orange)
                                Text(result.summary)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }

                            if !result.differences.isEmpty {
                                Text("Differences:")
                                    .font(.caption)
                                    .fontWeight(.medium)

                                ScrollView {
                                    Text(result.differences.joined(separator: "\n"))
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                                .frame(maxHeight: 150)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                    }
                }

                Divider()

                // Backup Growth Analysis
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.accentColor)
                        Text("Backup Growth Analysis")
                            .font(.headline)
                    }

                    Text("Analyze backup growth trends and storage patterns over time.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: calculateDrift) {
                        if isCalculatingDrift {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 20, height: 20)
                        } else {
                            Label("Calculate Growth", systemImage: "chart.bar")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isCalculatingDrift)

                    if let drift = driftAnalysis {
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Total Backups", value: "\(drift.totalBackups)")
                            InfoRow(label: "Growth Trend", value: drift.growthTrend)

                            if !drift.details.isEmpty {
                                Text("Details:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.top, 4)

                                ScrollView {
                                    Text(drift.details)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                                .frame(maxHeight: 150)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                    }
                }

                Divider()

                // All Backups List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "list.bullet")
                            .foregroundColor(.accentColor)
                        Text("All Backups")
                            .font(.headline)

                        Spacer()

                        Button(action: loadAllBackups) {
                            if isLoadingBackups {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 20, height: 20)
                            } else {
                                Label("Load", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoadingBackups)
                    }

                    if !allBackups.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(allBackups.prefix(10)) { backup in
                                HStack {
                                    Text(backup.formattedDate)
                                        .font(.system(.caption, design: .monospaced))
                                    Spacer()
                                    Button(action: {
                                        copyToClipboard(backup.path)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }

                            if allBackups.count > 10 {
                                Text("... and \(allBackups.count - 10) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(10)
                    }
                }

                Spacer()
            }
            .padding()
        }
    }

    private func compareToBackup() {
        isComparingBackup = true
        Task {
            let result = await fetchComparison()
            await MainActor.run {
                comparisonResult = result
                isComparingBackup = false
            }
        }
    }

    private func calculateDrift() {
        isCalculatingDrift = true
        Task {
            let drift = await fetchDrift()
            await MainActor.run {
                driftAnalysis = drift
                isCalculatingDrift = false
            }
        }
    }

    private func loadAllBackups() {
        isLoadingBackups = true
        Task {
            let backups = await fetchAllBackups()
            await MainActor.run {
                allBackups = backups
                isLoadingBackups = false
            }
        }
    }

    nonisolated private func fetchComparison() async -> ComparisonResult {
        return await TimeMachineManager.shared.compareToLatestBackup()
    }

    nonisolated private func fetchDrift() async -> DriftAnalysis {
        return await TimeMachineManager.shared.calculateBackupDrift()
    }

    nonisolated private func fetchAllBackups() async -> [BackupInfo] {
        return await TimeMachineManager.shared.listAllBackups()
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func exportComparisonToCSV(_ result: ComparisonResult) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Export Comparison Results"
        savePanel.message = "Choose a location to save the comparison results"
        savePanel.nameFieldLabel = "File Name:"

        // Generate default filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        savePanel.nameFieldStringValue = "TimeMachine_Comparison_\(timestamp).csv"

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }

            do {
                let csvContent = result.exportToCSV()
                try csvContent.write(to: url, atomically: true, encoding: .utf8)

                // Show success notification
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Export Successful"
                    alert.informativeText = "Comparison results saved to:\n\(url.path)"
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            } catch {
                // Show error notification
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Export Failed"
                    alert.informativeText = "Could not save CSV file: \(error.localizedDescription)"
                    alert.alertStyle = .critical
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
}

#Preview {
    AdvancedToolsView(viewModel: SnapshotViewModel())
}
