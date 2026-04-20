//
//  TimeMachineManager.swift
//  Time Machine Manager
//
//  Created by RamosTech on 11/12/25.
//

import Foundation
import AppKit

final class TimeMachineManager: @unchecked Sendable {
    static let shared = TimeMachineManager()

    private init() {}

    // MARK: - Shell Execution

    private func executeShellCommand(_ command: String) -> (output: String, error: String, exitCode: Int32) {
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.arguments = ["-c", command]
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.standardInput = nil

        do {
            try task.run()
            task.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            return (output, error, task.terminationStatus)
        } catch {
            return ("", error.localizedDescription, 1)
        }
    }

    // MARK: - Time Machine Status

    func getStatus() async -> TMStatus {
        // Check if a backup is currently running
        let statusResult = executeShellCommand("tmutil status 2>/dev/null")
        if statusResult.output.contains("Running = 1") {
            return .running
        }

        // Check if Time Machine is enabled by reading the preference
        let autoBackupResult = executeShellCommand("defaults read /Library/Preferences/com.apple.TimeMachine.plist AutoBackup 2>/dev/null")
        let autoBackupValue = autoBackupResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

        if autoBackupValue == "1" {
            return .enabled
        } else {
            return .disabled
        }
    }

    // MARK: - Full Disk Access Check

    func hasFullDiskAccess() -> Bool {
        // Try to read Time Machine preferences - requires Full Disk Access
        let result = executeShellCommand("defaults read /Library/Preferences/com.apple.TimeMachine.plist 2>/dev/null")
        return result.exitCode == 0
    }

    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Privileged Operations

    func enableTimeMachine() async -> Result<Void, Error> {
        // Execute Terminal command and wait for it to open
        DispatchQueue.main.async {
            self.executeCommandInTerminal("sudo tmutil enable")
        }

        // Wait for Terminal to open before returning
        Thread.sleep(forTimeInterval: 1.0)

        return .failure(NSError(
            domain: "TimeMachine",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: """
            Terminal Opened

            A new Terminal tab has been opened with the command ready.

            Press ENTER to execute the command and enter your password when prompted.

            After the command completes, click Refresh in this app to see the updated status.
            """]
        ))
    }

    func disableTimeMachine() async -> Result<Void, Error> {
        // Execute Terminal command and wait for it to open
        DispatchQueue.main.async {
            self.executeCommandInTerminal("sudo tmutil disable")
        }

        // Wait for Terminal to open before returning
        Thread.sleep(forTimeInterval: 1.0)

        return .failure(NSError(
            domain: "TimeMachine",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: """
            Terminal Opened

            A new Terminal tab has been opened with the command ready.

            Press ENTER to execute the command and enter your password when prompted.

            After the command completes, click Refresh in this app to see the updated status.
            """]
        ))
    }

    private func executeCommandInTerminal(_ command: String) {
        // Open Terminal in a new tab and execute the command
        let script = """
        tell application "Terminal"
            activate
            if (count of windows) is 0 then
                do script "\(command)"
            else
                tell application "System Events"
                    keystroke "t" using command down
                end tell
                delay 0.5
                do script "\(command)" in front window
            end if
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }


    // MARK: - Destination Info

    func getDestinationInfo() async -> DestinationInfo {
        let result = executeShellCommand("tmutil destinationinfo")
        let output = result.output

        if output.isEmpty {
            // Return empty but valid structure
            return DestinationInfo(name: "", kind: "", id: "", mountPoint: nil)
        }

        // Parse destination information
        let lines = output.components(separatedBy: .newlines)
        var name = ""
        var kind = ""
        var id = ""
        var mountPoint: String?

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines and separator lines
            if trimmedLine.isEmpty || trimmedLine.starts(with: "=") {
                continue
            }

            // Split by colon to get key and value
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

            switch key {
            case "Name":
                name = value
            case "Kind":
                kind = value
            case "ID":
                id = value
            case "Mount Point":
                if !value.isEmpty {
                    mountPoint = value
                }
            default:
                break
            }
        }

        return DestinationInfo(name: name, kind: kind, id: id, mountPoint: mountPoint)
    }

    // MARK: - Disk Space

    func getDiskSpace() async -> DiskSpace {
        let result = executeShellCommand("df -h / | tail -1")
        let components = result.output.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        guard components.count >= 5 else {
            return DiskSpace(total: "N/A", used: "N/A", available: "N/A", percentUsed: "N/A")
        }

        return DiskSpace(
            total: components[1],
            used: components[2],
            available: components[3],
            percentUsed: components[4]
        )
    }

    // MARK: - Snapshots

    func listSnapshots() async -> [Snapshot] {
        let result = executeShellCommand("tmutil listlocalsnapshots / 2>/dev/null")
        let output = result.output

        guard !output.isEmpty else { return [] }

        let lines = output.components(separatedBy: .newlines)
            .filter { $0.contains("com.apple.TimeMachine") }

        return lines.compactMap { line -> Snapshot? in
            let fullName = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Extract date part: com.apple.TimeMachine.2025-11-04-174502.local -> 2025-11-04-174502
            let parts = fullName.components(separatedBy: ".")
            guard parts.count >= 4 else { return nil }
            let datePart = parts[3] // The date is always the 4th component (index 3)

            // Parse date: 2024-01-15-120000
            guard datePart.count >= 17 else { return nil }

            let yearStr = String(datePart.prefix(4))
            let monthStr = String(datePart.dropFirst(5).prefix(2))
            let dayStr = String(datePart.dropFirst(8).prefix(2))
            let hourStr = String(datePart.dropFirst(11).prefix(2))
            let minuteStr = String(datePart.dropFirst(13).prefix(2))
            let secondStr = String(datePart.dropFirst(15).prefix(2))

            guard let year = Int(yearStr),
                  let month = Int(monthStr),
                  let day = Int(dayStr),
                  let hour = Int(hourStr),
                  let minute = Int(minuteStr),
                  let second = Int(secondStr) else { return nil }

            var dateComponents = DateComponents()
            dateComponents.year = year
            dateComponents.month = month
            dateComponents.day = day
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.second = second

            guard let date = Calendar.current.date(from: dateComponents) else { return nil }

            return Snapshot(fullName: fullName, date: date, datePart: datePart)
        }
        .sorted { $0.date > $1.date } // Most recent first
    }

    func deleteSnapshot(_ snapshot: Snapshot) async -> Result<Void, Error> {
        // Execute Terminal command and wait for it to open
        DispatchQueue.main.async {
            self.executeCommandInTerminal("sudo tmutil deletelocalsnapshots \(snapshot.datePart)")
        }

        // Wait for Terminal to open before returning
        Thread.sleep(forTimeInterval: 1.0)

        return .failure(NSError(
            domain: "TimeMachine",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: """
            Terminal Opened

            A new Terminal tab has been opened with the command ready to delete this snapshot.

            Press ENTER to execute the command and enter your password when prompted.

            After the command completes, click Refresh in this app to see the updated snapshot list.
            """]
        ))
    }

    func getSnapshotDetails(_ snapshot: Snapshot) async -> SnapshotDetails {
        let destInfo = await getDestinationInfo()
        let diskSpace = await getDiskSpace()

        // Get APFS info
        let apfsResult = executeShellCommand("diskutil apfs listSnapshots / 2>/dev/null | grep -B2 -A8 '\(snapshot.datePart)' 2>/dev/null")
        let apfsInfo = apfsResult.output.isEmpty ? "Not available" : apfsResult.output

        // Get latest backup to external drive
        let latestResult = executeShellCommand("tmutil latestbackup 2>/dev/null")
        var latestBackup = "No backup to external drive"

        if !latestResult.output.isEmpty {
            let trimmedOutput = latestResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

            // Try to extract date from path
            let regex = try? NSRegularExpression(pattern: "[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}")
            if let match = regex?.firstMatch(in: trimmedOutput, range: NSRange(trimmedOutput.startIndex..., in: trimmedOutput)) {
                if let range = Range(match.range, in: trimmedOutput) {
                    let dateStr = String(trimmedOutput[range])
                    // Format: 2024-01-15-120000 -> 2024-01-15 12:00:00
                    if dateStr.count >= 17 {
                        let year = dateStr.prefix(4)
                        let month = dateStr.dropFirst(5).prefix(2)
                        let day = dateStr.dropFirst(8).prefix(2)
                        let hour = dateStr.dropFirst(11).prefix(2)
                        let minute = dateStr.dropFirst(13).prefix(2)
                        let second = dateStr.dropFirst(15).prefix(2)
                        latestBackup = "\(year)-\(month)-\(day) \(hour):\(minute):\(second)"
                    } else {
                        latestBackup = dateStr
                    }
                }
            } else {
                // No date found, show the path
                latestBackup = trimmedOutput
            }
        }

        return SnapshotDetails(
            snapshot: snapshot,
            destination: destInfo,
            latestBackup: latestBackup,
            apfsInfo: apfsInfo,
            diskSpace: diskSpace
        )
    }

    // MARK: - Estimated Size

    func estimateSnapshotSize(count: Int) -> String {
        guard count > 0 else { return "0 GB" }

        // Estimate: typically 2-8GB per snapshot, using 4GB average
        let estimate = count * 4

        if estimate < 1 {
            return "< 1 GB"
        } else {
            return "~\(estimate) GB"
        }
    }

    // MARK: - Advanced Snapshot Management

    func getUniqueSize(for snapshot: Snapshot) async -> String {
        // Get unique size for specific snapshot by mounting it
        let result = executeShellCommand("tmutil uniquesize /")
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)

        if output.isEmpty {
            return "Unable to calculate"
        }

        return output
    }

    func thinLocalSnapshots(volumePath: String = "/", purgeAmountGB: Int, urgency: Int = 2) -> Result<String, Error> {
        // Convert GB to bytes
        let purgeBytes = Int64(purgeAmountGB) * 1_073_741_824

        let command = "sudo tmutil thinlocalsnapshots \(volumePath) \(purgeBytes) \(urgency)"

        // Return command for user to copy
        return .failure(NSError(
            domain: "TimeMachine",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: """
            Copy this command to Terminal:

            \(command)

            This will reclaim approximately \(purgeAmountGB) GB by thinning local snapshots.
            Urgency level \(urgency): \(urgency == 1 ? "Low (completes backups first)" : urgency == 4 ? "High (stops backups to free space)" : "Medium")
            """]
        ))
    }

    // MARK: - Exclusion Management

    func listExcludedItems() async -> [ExcludedItem] {
        // Get all excluded items from system preferences
        let result = executeShellCommand("defaults read /Library/Preferences/com.apple.TimeMachine.plist SkipPaths 2>/dev/null")
        let output = result.output

        guard !output.isEmpty else { return [] }

        // Parse plist array output
        var items: [ExcludedItem] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove quotes and commas
            let cleaned = trimmed.replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: ",", with: "")

            if !cleaned.isEmpty && cleaned != "(" && cleaned != ")" {
                items.append(ExcludedItem(path: cleaned, type: .fixed))
            }
        }

        return items
    }

    func checkExclusionStatus(path: String) -> ExclusionStatus {
        let result = executeShellCommand("tmutil isexcluded \"\(path)\"")
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)

        if output.contains("[Excluded]") {
            if output.contains("(Sticky)") {
                return .excluded(.sticky)
            } else if output.contains("(Fixed-path)") {
                return .excluded(.fixed)
            } else {
                return .excluded(.unknown)
            }
        }

        return .notExcluded
    }

    func excludePath(_ path: String, type: ExclusionType) -> Result<Void, Error> {
        let flag = type == .sticky ? "" : "-p"
        let command = "tmutil addexclusion \(flag) \"\(path)\""

        return .failure(NSError(
            domain: "TimeMachine",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: """
            Copy this command to Terminal:

            \(command)

            This will exclude the path from Time Machine backups.
            Type: \(type.rawValue)
            """]
        ))
    }

    func includePath(_ path: String, type: ExclusionType) -> Result<Void, Error> {
        let flag = type == .sticky ? "" : "-p"
        let command = "tmutil removeexclusion \(flag) \"\(path)\""

        return .failure(NSError(
            domain: "TimeMachine",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: """
            Copy this command to Terminal:

            \(command)

            This will include the path in Time Machine backups (remove exclusion).
            Type: \(type.rawValue)
            """]
        ))
    }

    // MARK: - Backup Analysis

    func compareToLatestBackup(path: String = "~/") async -> ComparisonResult {
        let result = executeShellCommand("tmutil compare -a \"\(path)\" 2>/dev/null")
        let output = result.output

        if output.isEmpty {
            return ComparisonResult(identical: true, differences: [], summary: "No differences found")
        }

        // Parse differences
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var differences: [String] = []

        for line in lines {
            if line.starts(with: "!") || line.starts(with: "+") || line.starts(with: "-") {
                differences.append(line)
            }
        }

        let summary = differences.isEmpty ? "No differences found" : "\(differences.count) differences found"

        return ComparisonResult(
            identical: differences.isEmpty,
            differences: differences,
            summary: summary
        )
    }

    func calculateBackupDrift() async -> DriftAnalysis {
        let result = executeShellCommand("tmutil calculatedrift 2>/dev/null")
        let output = result.output

        if output.isEmpty {
            return DriftAnalysis(
                totalBackups: 0,
                averageSize: "N/A",
                growthTrend: "Unable to calculate",
                details: "No backup data available"
            )
        }

        // Parse drift output
        var totalBackups = 0
        var details: [String] = []

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if !line.isEmpty {
                details.append(line)
                if line.contains("backup") {
                    totalBackups += 1
                }
            }
        }

        return DriftAnalysis(
            totalBackups: totalBackups,
            averageSize: "Calculating...",
            growthTrend: output.contains("increasing") ? "Increasing" : "Stable",
            details: output
        )
    }

    func verifyBackupIntegrity(path: String? = nil) -> IntegrityCheckResult {
        let command = path != nil ? "tmutil verifychecksums \"\(path!)\" 2>&1" : "tmutil verifychecksums 2>&1"
        let result = executeShellCommand(command)
        let output = result.output

        let passed = result.exitCode == 0 && !output.contains("error") && !output.contains("failed")

        return IntegrityCheckResult(
            passed: passed,
            details: output.isEmpty ? "Verification complete" : output,
            errors: passed ? [] : output.components(separatedBy: .newlines).filter { $0.contains("error") }
        )
    }

    func listAllBackups() async -> [BackupInfo] {
        let result = executeShellCommand("tmutil listbackups 2>/dev/null")
        let output = result.output

        guard !output.isEmpty else { return [] }

        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }

        return lines.compactMap { line -> BackupInfo? in
            // Extract date from path like: /Volumes/Backup/Backups.backupdb/MacBook/2025-01-15-123456
            let components = line.components(separatedBy: "/")
            guard let datePart = components.last else { return nil }

            // Parse date
            guard datePart.count >= 17 else { return nil }

            let yearStr = String(datePart.prefix(4))
            let monthStr = String(datePart.dropFirst(5).prefix(2))
            let dayStr = String(datePart.dropFirst(8).prefix(2))
            let hourStr = String(datePart.dropFirst(11).prefix(2))
            let minuteStr = String(datePart.dropFirst(13).prefix(2))
            let secondStr = String(datePart.dropFirst(15).prefix(2))

            guard let year = Int(yearStr),
                  let month = Int(monthStr),
                  let day = Int(dayStr),
                  let hour = Int(hourStr),
                  let minute = Int(minuteStr),
                  let second = Int(secondStr) else { return nil }

            var dateComponents = DateComponents()
            dateComponents.year = year
            dateComponents.month = month
            dateComponents.day = day
            dateComponents.hour = hour
            dateComponents.minute = minute
            dateComponents.second = second

            guard let date = Calendar.current.date(from: dateComponents) else { return nil }

            return BackupInfo(path: line, date: date)
        }
        .sorted { $0.date > $1.date }
    }
}

// MARK: - Models

enum TMStatus: String, Sendable {
    case running = "Running"
    case enabled = "Enabled"
    case disabled = "Disabled"
}

struct DestinationInfo: Sendable {
    let name: String
    let kind: String
    let id: String
    let mountPoint: String?

    var isConfigured: Bool {
        !name.isEmpty
    }

    var displayName: String {
        if !name.isEmpty {
            return name
        }
        return "Not configured"
    }

    var kindDescription: String {
        switch kind.lowercased() {
        case "local":
            return "Local Drive"
        case "network":
            return "Network Drive"
        default:
            return kind
        }
    }

    var summary: String {
        if !name.isEmpty {
            return "\(name) (\(kindDescription))"
        }
        return "Not configured"
    }

    var detailedDescription: String {
        var details: [String] = []

        if !name.isEmpty {
            details.append("Name: \(name)")
        }

        if !kind.isEmpty {
            details.append("Type: \(kindDescription)")
        }

        if !id.isEmpty {
            details.append("ID: \(id)")
        }

        if let mount = mountPoint, !mount.isEmpty {
            details.append("Path: \(mount)")
        }

        return details.isEmpty ? "Not configured" : details.joined(separator: "\n")
    }
}

struct Snapshot: Identifiable, Hashable, Sendable {
    let id = UUID()
    let fullName: String
    let date: Date
    let datePart: String

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    var age: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day, .hour, .minute], from: date, to: now)

        if let days = components.day, days > 0 {
            let hours = components.hour ?? 0
            return "\(days) day\(days == 1 ? "" : "s"), \(hours) hour\(hours == 1 ? "" : "s")"
        } else if let hours = components.hour, hours > 0 {
            let minutes = components.minute ?? 0
            return "\(hours) hour\(hours == 1 ? "" : "s"), \(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let minutes = components.minute ?? 0
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
}

struct DiskSpace: Sendable {
    let total: String
    let used: String
    let available: String
    let percentUsed: String

    var description: String {
        "Total: \(total) | Used: \(used) | Available: \(available) (\(percentUsed) full)"
    }
}

struct SnapshotDetails: Sendable {
    let snapshot: Snapshot
    let destination: DestinationInfo
    let latestBackup: String
    let apfsInfo: String
    let diskSpace: DiskSpace
}

// MARK: - Advanced Management Models

enum ExclusionType: String, Sendable {
    case sticky = "Sticky"
    case fixed = "Fixed-path"
    case unknown = "Unknown"
}

enum ExclusionStatus: Sendable {
    case excluded(ExclusionType)
    case notExcluded

    var isExcluded: Bool {
        switch self {
        case .excluded:
            return true
        case .notExcluded:
            return false
        }
    }

    var description: String {
        switch self {
        case .excluded(let type):
            return "Excluded (\(type.rawValue))"
        case .notExcluded:
            return "Not Excluded"
        }
    }
}

struct ExcludedItem: Identifiable, Sendable {
    let id = UUID()
    let path: String
    let type: ExclusionType

    var displayName: String {
        (path as NSString).lastPathComponent
    }
}

struct ComparisonResult: Sendable {
    let identical: Bool
    let differences: [String]
    let summary: String

    func exportToCSV() -> String {
        var csv = "Change Type,File Path,Details\n"

        for difference in differences {
            let trimmed = difference.trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse the difference line
            // Format examples:
            // ! /path/to/file - modified
            // + /path/to/file - added
            // - /path/to/file - removed

            var changeType = "Modified"
            var filePath = trimmed
            let details = ""

            if trimmed.hasPrefix("!") {
                changeType = "Modified"
                filePath = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("+") {
                changeType = "Added"
                filePath = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("-") {
                changeType = "Removed"
                filePath = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            }

            // Escape CSV values (handle quotes and commas)
            let escapedPath = escapeCSVValue(filePath)
            let escapedDetails = escapeCSVValue(details)

            csv += "\(changeType),\(escapedPath),\(escapedDetails)\n"
        }

        return csv
    }

    private func escapeCSVValue(_ value: String) -> String {
        // If value contains comma, quote, or newline, wrap in quotes and escape quotes
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

struct DriftAnalysis: Sendable {
    let totalBackups: Int
    let averageSize: String
    let growthTrend: String
    let details: String
}

struct IntegrityCheckResult: Sendable {
    let passed: Bool
    let details: String
    let errors: [String]
}

struct BackupInfo: Identifiable, Sendable {
    let id = UUID()
    let path: String
    let date: Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
