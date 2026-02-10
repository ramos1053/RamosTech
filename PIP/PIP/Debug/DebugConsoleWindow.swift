//
//  DebugConsoleWindow.swift
//  PIP
//
//  Created by A. Ramos on 2025.
//  Copyright © 2025 RamosTech. All rights reserved.
//

import SwiftUI

struct DebugConsoleWindow: View {
    @ObservedObject var logger = DebugLogger.shared
    @State private var searchText = ""
    @State private var selectedLevel: DebugLogger.LogLevel? = nil
    @State private var autoScroll = true
    @State private var showPerformanceStats = false

    var filteredLogs: [DebugLogger.LogEntry] {
        logger.logs.filter { entry in
            let matchesSearch = searchText.isEmpty || entry.message.localizedCaseInsensitiveContains(searchText) || entry.category.localizedCaseInsensitiveContains(searchText)
            let matchesLevel = selectedLevel == nil || entry.level == selectedLevel
            return matchesSearch && matchesLevel
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Performance stats (if enabled)
            if showPerformanceStats {
                performanceView
                Divider()
            }

            // Logs view
            logsListView
        }
        .frame(minWidth: 800, minHeight: 400)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .frame(width: 250)

            // Level filter
            Menu {
                Button("All Levels") {
                    selectedLevel = nil
                }

                Divider()

                ForEach(DebugLogger.LogLevel.allCases, id: \.self) { level in
                    Button(action: { selectedLevel = level }) {
                        HStack {
                            Text("\(level.icon) \(level.displayName)")
                            if selectedLevel == level {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(selectedLevel?.displayName ?? "All Levels", systemImage: "line.3.horizontal.decrease.circle")
            }
            .help("Filter by log level")

            Divider()
                .frame(height: 20)

            // Debug logging toggle
            Toggle(isOn: $logger.isEnabled) {
                Label("Debug", systemImage: "ladybug")
            }
            .toggleStyle(.button)
            .help("Enable or disable debug logging")

            // Auto-scroll toggle
            Toggle(isOn: $autoScroll) {
                Label("Auto-scroll", systemImage: "arrow.down.to.line")
            }
            .toggleStyle(.button)
            .help("Automatically scroll to newest logs")

            // Performance stats toggle
            Toggle(isOn: $showPerformanceStats) {
                Label("Stats", systemImage: "chart.bar")
            }
            .toggleStyle(.button)
            .help("Show performance statistics")

            Divider()
                .frame(height: 20)

            // Clear button
            Button(action: {
                logger.clearLogs()
            }) {
                Label("Clear", systemImage: "trash")
            }
            .help("Clear all logs")

            // Export button
            Button(action: {
                if let url = logger.exportLogs() {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export logs to file")

            Spacer()

            // Log count
            Text("\(filteredLogs.count) logs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Performance View

    private var performanceView: some View {
        HStack(spacing: 24) {
            performanceMetric(
                title: "Memory",
                value: formatBytes(logger.performanceMetrics.memoryUsage),
                icon: "memorychip"
            )

            performanceMetric(
                title: "Operations",
                value: "\(logger.performanceMetrics.operationCount)",
                icon: "gearshape.2"
            )

            performanceMetric(
                title: "Avg Time",
                value: logger.performanceMetrics.operationCount > 0 ?
                    String(format: "%.3fs", logger.performanceMetrics.totalOperationTime / Double(logger.performanceMetrics.operationCount)) : "0s",
                icon: "clock"
            )

            performanceMetric(
                title: "File I/O",
                value: "\(logger.performanceMetrics.fileIOCount)",
                icon: "doc"
            )

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private func performanceMetric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.caption)
            Text(title + ":")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - Logs List

    private var logsListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredLogs) { entry in
                        logEntryView(entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 8)
            }
            .onChange(of: logger.logs.count) { _, _ in
                if autoScroll, let lastLog = filteredLogs.last {
                    withAnimation {
                        proxy.scrollTo(lastLog.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func logEntryView(_ entry: DebugLogger.LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(entry.formattedTimestamp)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            // Level icon
            Text(entry.level.icon)
                .font(.caption)
                .frame(width: 20)

            // Level text
            Text(entry.level.displayName)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(entry.level.color))
                .frame(width: 70, alignment: .leading)

            // Category
            Text("[\(entry.category)]")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(minWidth: 80, alignment: .leading)

            // Message
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(entry.level == .error || entry.level == .critical ? Color.red.opacity(0.05) : Color.clear)
        .cornerRadius(2)
        .contextMenu {
            Button("Copy Message") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.message, forType: .string)
            }

            Button("Copy Full Entry") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.formattedMessage, forType: .string)
            }
        }
    }

    // MARK: - Helper Methods

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    DebugConsoleWindow()
        .frame(width: 1000, height: 600)
}
