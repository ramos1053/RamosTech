//
//  ServerViewModel.swift
//  Nimbus-Swift
//

import Foundation
import AppKit
import Combine

@MainActor
class ServerViewModel: ObservableObject {
    @Published var isServerRunning: Bool = false
    @Published var lastMessage: String = ""
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var serverStatus: ServerStatus = .empty

    private let shellExecutor = ShellExecutor()
    private var monitoringTimer: Timer?

    // Start Cumulus Server
    func startServer(serverPath: String) async {
        let command = "\(serverPath)start-cumulus"

        do {
            let output = try await shellExecutor.execute(command: command)
            showSuccess(title: "Server Started", message: output)
            isServerRunning = true
        } catch {
            let friendlyMessage = makeFriendlyError(
                error: error,
                context: .serverPath,
                path: serverPath,
                operation: "start the Cumulus server"
            )
            showError(title: "Unable to Start Server", message: friendlyMessage)
        }
    }

    // Stop Cumulus Server
    func stopServer(serverPath: String) async {
        let command = "\(serverPath)stop-cumulus"

        do {
            let output = try await shellExecutor.execute(command: command)
            showSuccess(title: "Server Stopped", message: output)
            isServerRunning = false
        } catch {
            let friendlyMessage = makeFriendlyError(
                error: error,
                context: .serverPath,
                path: serverPath,
                operation: "stop the Cumulus server"
            )
            showError(title: "Unable to Stop Server", message: friendlyMessage)
        }
    }

    // Get server uptime
    func getServerUptime() async {
        do {
            let output = try await shellExecutor.execute(command: "uptime")
            showSuccess(title: "Server Uptime", message: output)
        } catch {
            showError(title: "Error", message: "Unable to get server uptime: \(error.localizedDescription)")
        }
    }

    // Backup catalogs
    func backupCatalogs(catalogPath: String, backupPath: String) async {
        let command = "cp -R '\(catalogPath)' '\(backupPath)'"

        do {
            _ = try await shellExecutor.execute(command: command)
            showSuccess(title: "Backup Complete", message: "Catalog backup operation was successful!")
        } catch {
            let friendlyMessage = makeFriendlyError(
                error: error,
                context: .catalogOrBackup,
                path: catalogPath,
                operation: "backup your catalogs",
                secondaryPath: backupPath
            )
            showError(title: "Backup Failed", message: friendlyMessage)
        }
    }

    // System maintenance - cleanup logs
    func cleanupSystemLogs() async {
        do {
            // Modern macOS log cleanup approach
            // 1. Clear old system log files
            // 2. Clear temporary files and crash reports
            let cleanupScript = """
            # Clear old log files
            find /private/var/log -name "*.old" -delete 2>/dev/null || true
            find /private/var/log -name "*.gz" -delete 2>/dev/null || true
            # Clear old crash reports
            find /Library/Logs/DiagnosticReports -name "*.crash" -mtime +7 -delete 2>/dev/null || true
            # Clear system.log archives
            rm -f /var/log/system.log.*.gz 2>/dev/null || true
            echo "✓ Cleaned old log files"
            echo "✓ Removed archived logs"
            echo "✓ Cleared old crash reports"
            """

            let output = try await shellExecutor.executeWithPrivileges(command: cleanupScript)
            showSuccess(title: "Maintenance Complete", message: "System logs and temporary files cleaned successfully!\n\n\(output)")
        } catch {
            showError(title: "Maintenance Error", message: "Log cleanup failed or was cancelled.\n\nError: \(error.localizedDescription)")
        }
    }

    // View system log
    func viewSystemLog() {
        let fileURL = URL(fileURLWithPath: "/var/log/system.log")
        NSWorkspace.shared.open(fileURL)
    }

    // Execute custom command
    func executeCommand(_ command: String) async {
        // Security: Don't allow certain dangerous commands
        let blocklist = ["ssh", "telnet", "fsck", "top", "status"]
        for blocked in blocklist {
            if command.lowercased().contains(blocked) {
                showError(title: "Command Blocked", message: "This command is not allowed for security reasons.")
                return
            }
        }

        do {
            let output = try await shellExecutor.execute(command: command)
            lastMessage = output
        } catch {
            showError(title: "Command Failed", message: error.localizedDescription)
        }
    }

    private func showSuccess(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    private func showError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    // MARK: - Server Monitoring

    func startMonitoring() {
        stopMonitoring() // Stop existing timer if any

        // Initial update
        Task {
            await updateServerStatus()
        }

        // Update every 2 seconds
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.updateServerStatus()
            }
        }
    }

    nonisolated func stopMonitoring() {
        Task { @MainActor in
            monitoringTimer?.invalidate()
            monitoringTimer = nil
        }
    }

    private var catalogPath: String = "/usr/local/Cumulus5/"

    func setCatalogPath(_ path: String) {
        catalogPath = path
    }

    private func updateServerStatus() async {
        // Check if server process is running
        let isRunning = await checkServerProcess()
        let uptime = await getUptime()
        let metrics = await getSystemMetrics()

        serverStatus = ServerStatus(
            isRunning: isRunning.running,
            processID: isRunning.pid,
            uptime: uptime,
            metrics: metrics
        )

        isServerRunning = isRunning.running
    }

    private func checkServerProcess() async -> (running: Bool, pid: Int?) {
        do {
            let output = try await shellExecutor.execute(command: "pgrep -fl cumulus | head -1")
            let components = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
            if let pidString = components.first, let pid = Int(pidString) {
                return (true, pid)
            }
        } catch {
            // Process not found
        }
        return (false, nil)
    }

    private func getUptime() async -> String {
        do {
            let output = try await shellExecutor.execute(command: "uptime | awk '{print $3, $4}' | sed 's/,//'")
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "Unknown"
        }
    }

    private func getSystemMetrics() async -> SystemMetrics {
        async let memory = getServerMemoryUsage()
        async let cpu = getServerCPUUsage()
        async let catalogSize = getCatalogSize()

        return await SystemMetrics(
            memoryUsageMB: memory,
            cpuUsage: cpu,
            catalogSizeGB: catalogSize,
            timestamp: Date()
        )
    }

    private func getServerMemoryUsage() async -> Double {
        guard let pid = serverStatus.processID else {
            return 0.0
        }

        do {
            // Get RSS (Resident Set Size) in KB, then convert to MB
            let output = try await shellExecutor.execute(command: "ps -o rss= -p \(pid)")
            if let rssKB = Double(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return rssKB / 1024.0 // Convert KB to MB
            }
        } catch {}
        return 0.0
    }

    private func getServerCPUUsage() async -> Double {
        guard let pid = serverStatus.processID else {
            return 0.0
        }

        do {
            // Get CPU percentage for the process
            let output = try await shellExecutor.execute(command: "ps -o %cpu= -p \(pid)")
            if let cpu = Double(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return cpu
            }
        } catch {}
        return 0.0
    }

    private func getCatalogSize() async -> Double {
        do {
            // Get total size of catalog directory in MB, then convert to GB
            // Using du -sm to get size in megabytes
            let escapedPath = catalogPath.replacingOccurrences(of: "'", with: "'\\''")
            let output = try await shellExecutor.execute(command: "du -sm '\(escapedPath)' 2>/dev/null | awk '{print $1}'")
            if let sizeMB = Double(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return sizeMB / 1024.0 // Convert MB to GB
            }
        } catch {}
        return 0.0
    }

    // MARK: - Error Handling

    private enum ErrorContext {
        case serverPath
        case catalogOrBackup
    }

    private func makeFriendlyError(
        error: Error,
        context: ErrorContext,
        path: String,
        operation: String,
        secondaryPath: String? = nil
    ) -> String {
        let errorDescription = error.localizedDescription.lowercased()

        // Check for common path-related errors
        if errorDescription.contains("no such file or directory") {
            switch context {
            case .serverPath:
                return """
                ❌ Server not found at this location:
                \(path)

                The Cumulus server installation could not be found at the configured path.

                📝 To fix this:
                1. Click the 'Preferences' button
                2. Update the 'Server Path' to point to your Cumulus installation
                3. Make sure the path ends with a forward slash (/)

                Example: /Applications/Cumulus/
                """

            case .catalogOrBackup:
                // Determine which path is the problem
                if errorDescription.contains(catalogPath) || path.contains(catalogPath) {
                    return """
                    ❌ Catalog directory not found:
                    \(path)

                    The catalog directory could not be found at the configured path.

                    📝 To fix this:
                    1. Click the 'Preferences' button
                    2. Update the 'Catalog Path' to point to your Cumulus catalogs
                    3. Make sure the directory exists

                    Example: /usr/local/Cumulus5/catalogs/
                    """
                } else if let backupPath = secondaryPath {
                    return """
                    ❌ Backup destination not found:
                    \(backupPath)

                    The backup directory could not be found or is not accessible.

                    📝 To fix this:
                    1. Click the 'Preferences' button
                    2. Update the 'Backup Path' to a valid destination
                    3. Make sure you have write permissions to this location

                    Example: /Volumes/Backup/Cumulus/
                    """
                }
            }
        }

        // Check for permission errors
        if errorDescription.contains("permission denied") {
            return """
            ❌ Permission denied

            You don't have permission to \(operation).

            📝 To fix this:
            • Check that you have read/write access to the directory
            • Make sure the Cumulus server has the correct file permissions
            • You may need administrator privileges for this operation
            """
        }

        // Check for command not found
        if errorDescription.contains("command not found") || errorDescription.contains("not found") {
            switch context {
            case .serverPath:
                return """
                ❌ Server command not found

                The start-cumulus or stop-cumulus command was not found at:
                \(path)

                📝 To fix this:
                1. Click the 'Preferences' button
                2. Verify your 'Server Path' points to the Cumulus installation directory
                3. Make sure the start-cumulus and stop-cumulus scripts exist

                The directory should contain the server control scripts.
                """
            default:
                break
            }
        }

        // Generic fallback with helpful hint
        return """
        Unable to \(operation).

        Error: \(error.localizedDescription)

        💡 Tip: Check your paths in Preferences to ensure they're correct.
        """
    }

    deinit {
        stopMonitoring()
    }
}
