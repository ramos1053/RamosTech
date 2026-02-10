import Foundation
import AppKit

/// Handles script execution with output logging
@MainActor
final class ScriptExecutor: ObservableObject {

    @Published var isRunning: Bool = false
    @Published var lastExecutionStatus: ExecutionStatus? = nil
    @Published var output: String = ""

    enum ExecutionStatus {
        case running
        case success
        case failure
    }

    private let preferences = AppPreferences.shared

    private var currentTask: Process?

    func clearOutput() {
        output = ""
    }

    // MARK: - Execution

    func executeCommand(_ command: String) async throws {
        guard !isRunning else {
            DebugLogger.shared.warning("Command execution blocked - another process is already running", category: "CommandExecution")
            return
        }

        isRunning = true
        lastExecutionStatus = .running

        DebugLogger.shared.info("Executing command: \(command)", category: "CommandExecution")

        let task = Process()
        currentTask = task

        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]

        // Set up output pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        // Set working directory to user's home directory
        task.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        // Set up clean environment
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        environment["USER"] = NSUserName()
        environment["SHELL"] = "/bin/bash"
        environment["TMPDIR"] = FileManager.default.temporaryDirectory.path
        task.environment = environment

        // Read output asynchronously
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading

        outputHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let outputText = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.output += outputText
                }
            }
        }

        errorHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let outputText = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    self?.output += outputText
                }
            }
        }

        do {
            try task.run()

            // Wait for completion
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                task.terminationHandler = { _ in
                    continuation.resume()
                }
            }

            // Clean up handlers
            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil

            let exitCode = task.terminationStatus

            if exitCode == 0 {
                DebugLogger.shared.info("✅ Command completed successfully", category: "CommandExecution")
                lastExecutionStatus = .success
            } else {
                DebugLogger.shared.error("❌ Command failed with exit code: \(exitCode)", category: "CommandExecution")
                lastExecutionStatus = .failure
            }

        } catch {
            DebugLogger.shared.error("Failed to execute command: \(error.localizedDescription)", category: "CommandExecution")
            lastExecutionStatus = .failure
            throw error
        }

        isRunning = false
        currentTask = nil
    }

    func executeScript(content: String, format: FileFormat, url: URL? = nil) async throws {
        guard !isRunning else {
            DebugLogger.shared.warning("Script execution blocked - another script is already running", category: "ScriptExecution")
            return
        }

        isRunning = true
        lastExecutionStatus = .running

        let scriptName = url?.lastPathComponent ?? "untitled script"
        DebugLogger.shared.info("Starting script execution: \(scriptName)", category: "ScriptExecution")

        do {
            switch format {
            case .shell, .bash, .zsh:
                try await executeShellScript(content: content, url: url, interpreter: "/bin/bash")
            case .python:
                try await executeShellScript(content: content, url: url, interpreter: "/usr/bin/python3")
            case .ruby:
                try await executeShellScript(content: content, url: url, interpreter: "/usr/bin/ruby")
            case .perl:
                try await executeShellScript(content: content, url: url, interpreter: "/usr/bin/perl")
            case .javascript:
                try await executeShellScript(content: content, url: url, interpreter: "/usr/bin/node")
            case .php:
                try await executeShellScript(content: content, url: url, interpreter: "/usr/bin/php")
            default:
                let error = NSError(domain: "ScriptExecutor", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "File format '\(format.displayName)' is not executable"
                ])
                DebugLogger.shared.error("Unsupported file format for execution: \(format.displayName)", category: "ScriptExecution")
                throw error
            }
        } catch {
            DebugLogger.shared.error("Script execution failed: \(error.localizedDescription)", category: "ScriptExecution")
            lastExecutionStatus = .failure
            isRunning = false
            throw error
        }

        isRunning = false
        DebugLogger.shared.info("Script execution completed: \(scriptName)", category: "ScriptExecution")
    }

    private func executeShellScript(content: String, url: URL?, interpreter: String = "/bin/bash") async throws {
        // Track if stderr received any output (indicates errors even if exit code is 0)
        // Using a class to allow capture and mutation in closures
        class StderrTracker {
            var hasOutput = false
        }
        let stderrTracker = StderrTracker()

        // Pre-flight check: Run shellcheck if available and script is bash
        if interpreter == "/bin/bash" {
            await runShellcheck(content: content, originalURL: url)
        }

        // Always copy script to temp directory to avoid permission issues
        let tempDir = preferences.tempScriptDirectoryURL

        // Ensure temp directory exists
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)

        // Determine file extension based on interpreter
        let fileExtension: String
        switch interpreter {
        case "/usr/bin/python3": fileExtension = "py"
        case "/usr/bin/ruby": fileExtension = "rb"
        case "/usr/bin/perl": fileExtension = "pl"
        case "/usr/bin/node": fileExtension = "js"
        case "/usr/bin/php": fileExtension = "php"
        default: fileExtension = "sh"
        }

        let scriptURL = tempDir.appendingPathComponent("pip_temp_script_\(UUID().uuidString).\(fileExtension)")

        try content.write(to: scriptURL, atomically: true, encoding: .utf8)

        // Make executable with restrictive permissions (owner only)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

        defer {
            try? FileManager.default.removeItem(at: scriptURL)
        }

        if let originalURL = url {
            DebugLogger.shared.info("Executing: \(originalURL.path)", category: "ScriptExecution")
        } else {
            DebugLogger.shared.info("Executing script", category: "ScriptExecution")
        }

        let task = Process()
        currentTask = task

        task.executableURL = URL(fileURLWithPath: interpreter)

        // Add verbose flags based on interpreter and preference
        var arguments: [String] = []
        if preferences.verboseScriptOutput {
            switch interpreter {
            case "/bin/bash", "/bin/sh", "/bin/zsh":
                // Use -x flag to trace command execution
                arguments.append("-x")
            case "/usr/bin/python3", "/usr/bin/python":
                // Use -u for unbuffered output
                arguments.append("-u")
            case "/usr/bin/ruby":
                // Use -v for verbose mode
                arguments.append("-v")
            case "/usr/bin/perl":
                // Use -w for warnings
                arguments.append("-w")
            default:
                break
            }
        }
        arguments.append(scriptURL.path)
        task.arguments = arguments

        // Set up output pipes
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        // Set working directory to user's home directory (safe and always accessible)
        task.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

        // Set up clean environment
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
        environment["USER"] = NSUserName()
        environment["SHELL"] = "/bin/bash"
        environment["TMPDIR"] = FileManager.default.temporaryDirectory.path

        // Enable GUI dialogs for osascript and other tools
        // Inherit DISPLAY and other display-related environment variables
        if let display = ProcessInfo.processInfo.environment["DISPLAY"] {
            environment["DISPLAY"] = display
        }

        task.environment = environment

        // Read output asynchronously
        let outputHandle = outputPipe.fileHandleForReading
        let errorHandle = errorPipe.fileHandleForReading

        outputHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let outputText = String(data: data, encoding: .utf8) {
                Task { @MainActor in
                    let trimmedOutput = outputText.trimmingCharacters(in: .newlines)
                    DebugLogger.shared.debug("STDOUT: \(trimmedOutput)", category: "ScriptOutput")

                    // Always append output in real-time
                    self?.output += outputText
                }
            }
        }

        errorHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let outputText = String(data: data, encoding: .utf8) {
                stderrTracker.hasOutput = true
                Task { @MainActor in
                    let trimmedOutput = outputText.trimmingCharacters(in: .newlines)

                    // Only log raw STDERR in debug mode, parse errors for user-friendly display
                    #if DEBUG
                    DebugLogger.shared.debug("Raw STDERR: \(trimmedOutput)", category: "ScriptOutput")
                    #endif

                    // Extract and log line numbers from error messages
                    ScriptExecutor.parseError(trimmedOutput, scriptURL: scriptURL, originalURL: url)

                    // Always append error output in real-time
                    self?.output += outputText
                }
            }
        }

        do {
            try task.run()

            // Wait for completion
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                task.terminationHandler = { _ in
                    continuation.resume()
                }
            }

            // Clean up handlers
            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil

            let exitCode = task.terminationStatus

            // When verbose mode is enabled, stderr contains trace output, so only check exit code
            // When verbose mode is disabled, also check for stderr output
            let scriptFailed = if preferences.verboseScriptOutput {
                exitCode != 0
            } else {
                exitCode != 0 || stderrTracker.hasOutput
            }

            if !scriptFailed {
                DebugLogger.shared.info("✅ Script completed successfully (exit code: 0, no errors)", category: "ScriptExecution")
                lastExecutionStatus = .success
            } else {
                if exitCode != 0 {
                    DebugLogger.shared.error("❌ Script failed with exit code: \(exitCode)", category: "ScriptExecution")
                } else {
                    DebugLogger.shared.error("❌ Script completed with errors (stderr output detected)", category: "ScriptExecution")
                }
                lastExecutionStatus = .failure
            }

        } catch {
            DebugLogger.shared.error("Failed to execute script: \(error.localizedDescription)", category: "ScriptExecution")
            lastExecutionStatus = .failure
            throw error
        }

        currentTask = nil
    }

    // MARK: - Control

    func stopExecution() {
        guard let task = currentTask, task.isRunning else { return }

        DebugLogger.shared.warning("⚠️ User requested script termination", category: "ScriptExecution")
        task.terminate()

        // Force kill if still running after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if task.isRunning {
                task.interrupt()
                DebugLogger.shared.warning("Script forcefully killed after timeout", category: "ScriptExecution")
            }
        }

        isRunning = false
    }

    // MARK: - Error Parsing

    /// Parse error messages to extract line numbers and provide debugging context
    private static func parseError(_ errorMessage: String, scriptURL: URL, originalURL: URL? = nil) {
        let fileName = originalURL?.lastPathComponent ?? "script"

        // Error patterns for different languages:
        // Bash/Shell: "line 5: command not found" or "/path/script.sh: line 10: error"
        // Python: "File \"script.py\", line 5" or "script.py:5:"
        // Ruby: "script.rb:5:in" or "script.rb:5: syntax error"
        // Perl: "at script.pl line 5" or "script.pl line 5"
        // JavaScript: "script.js:5:10" or "at script.js:5:10"
        // PHP: "on line 5" or "Parse error: ... in script.php on line 5"

        let linePatterns = [
            // Shell/Bash patterns
            "line\\s+(\\d+):",           // "line 5:" or ": line 5:"
            "line\\s+(\\d+)",            // "line 5"

            // Python patterns
            "line\\s+(\\d+)",            // "File \"x.py\", line 5"
            ",\\s*line\\s+(\\d+)",       // ", line 5"

            // Ruby/JavaScript/TypeScript patterns
            ":(\\d+):",                  // "script.rb:5:" or "script.js:5:10"
            ":(\\d+)\\s+",               // "script.rb:5 "

            // Perl/PHP patterns
            "on\\s+line\\s+(\\d+)",      // "on line 5"
            "at\\s+.*?line\\s+(\\d+)",   // "at script.pl line 5"
        ]

        for pattern in linePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(errorMessage.startIndex..., in: errorMessage)
                if let match = regex.firstMatch(in: errorMessage, range: range),
                   match.numberOfRanges > 1 {
                    let lineNumRange = match.range(at: 1)
                    if let swiftRange = Range(lineNumRange, in: errorMessage),
                       let lineNumber = Int(errorMessage[swiftRange]) {

                        // Log detailed error with line number
                        let errorContext = extractErrorContext(from: errorMessage)

                        DebugLogger.shared.error(
                            "❌ Line \(lineNumber) in \(fileName): \(errorContext)",
                            category: "ScriptError"
                        )

                        // Try to read the script content and show the problematic line
                        if let scriptContent = try? String(contentsOf: scriptURL, encoding: .utf8) {
                            let lines = scriptContent.components(separatedBy: .newlines)
                            if lineNumber > 0 && lineNumber <= lines.count {
                                let contextLines = getContextLines(from: lines, around: lineNumber - 1)
                                DebugLogger.shared.error(
                                    "\(contextLines)",
                                    category: "ScriptError"
                                )
                            }
                        }

                        // Provide actionable suggestions
                        let suggestions = analyzeError(errorMessage, scriptURL: scriptURL, originalURL: originalURL)
                        if !suggestions.isEmpty {
                            DebugLogger.shared.info(suggestions, category: "Solution")
                        }

                        return // Found and logged the error, exit
                    }
                }
            }
        }

        // If no line number found, still log the error with context
        if errorMessage.contains("error") || errorMessage.contains("Error") ||
           errorMessage.contains("failed") || errorMessage.contains("Failed") {
            let errorContext = extractErrorContext(from: errorMessage)

            DebugLogger.shared.error(
                "❌ Error in \(fileName): \(errorContext)",
                category: "ScriptError"
            )

            // Provide actionable suggestions even without line number
            let suggestions = analyzeError(errorMessage, scriptURL: scriptURL, originalURL: originalURL)
            if !suggestions.isEmpty {
                DebugLogger.shared.info(suggestions, category: "Solution")
            }
        }
    }

    /// Extract meaningful error context from error message
    private static func extractErrorContext(from message: String) -> String {
        // Remove path prefixes and clean up the message
        var cleaned = message
            .replacingOccurrences(of: "^.*/", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // If message is too long, truncate but keep the important parts
        if cleaned.count > 200 {
            let firstPart = cleaned.prefix(100)
            let lastPart = cleaned.suffix(80)
            cleaned = "\(firstPart)...\(lastPart)"
        }

        return cleaned
    }

    /// Get code context around an error line
    private static func getContextLines(from lines: [String], around lineIndex: Int, contextSize: Int = 2) -> String {
        let startLine = max(0, lineIndex - contextSize)
        let endLine = min(lines.count - 1, lineIndex + contextSize)

        var result = ""
        for i in startLine...endLine {
            let lineNum = i + 1
            let marker = (i == lineIndex) ? "→" : " "
            let line = lines[i]
            result += String(format: "%3d %@ %@\n", lineNum, marker, line)
        }

        return result
    }

    // MARK: - Cleanup

    /// Clean up temporary script files older than the specified number of days
    func cleanupTempScripts(olderThanDays days: Int = 7) {
        let tempDir = preferences.tempScriptDirectoryURL

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        for fileURL in files {
            // Only clean up PIP temp scripts (all supported extensions)
            let fileName = fileURL.lastPathComponent
            guard fileName.hasPrefix("pip_temp_script_") &&
                  (fileName.hasSuffix(".sh") || fileName.hasSuffix(".py") ||
                   fileName.hasSuffix(".rb") || fileName.hasSuffix(".pl") ||
                   fileName.hasSuffix(".js") || fileName.hasSuffix(".php")) else { continue }

            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < cutoffDate {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    /// Clean up all temporary script files in the temp directory
    func cleanupAllTempScripts() {
        let tempDir = preferences.tempScriptDirectoryURL

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for fileURL in files {
            // Only clean up PIP temp scripts (all supported extensions)
            let fileName = fileURL.lastPathComponent
            guard fileName.hasPrefix("pip_temp_script_") &&
                  (fileName.hasSuffix(".sh") || fileName.hasSuffix(".py") ||
                   fileName.hasSuffix(".rb") || fileName.hasSuffix(".pl") ||
                   fileName.hasSuffix(".js") || fileName.hasSuffix(".php")) else { continue }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }


    // MARK: - Pre-flight Checks

    /// Run shellcheck on the script to catch potential issues before execution
    private func runShellcheck(content: String, originalURL: URL?) async {
        // Check if shellcheck is available
        let checkShellcheck = Process()
        checkShellcheck.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        checkShellcheck.arguments = ["shellcheck"]
        let checkPipe = Pipe()
        checkShellcheck.standardOutput = checkPipe
        checkShellcheck.standardError = checkPipe

        do {
            try checkShellcheck.run()
            checkShellcheck.waitUntilExit()

            guard checkShellcheck.terminationStatus == 0 else {
                // shellcheck not available
                return
            }
        } catch {
            return
        }

        // Write content to temp file for shellcheck
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("shellcheck_\(UUID().uuidString).sh")

        do {
            try content.write(to: tempFile, atomically: true, encoding: .utf8)
            defer {
                try? FileManager.default.removeItem(at: tempFile)
            }

            // Run shellcheck
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/local/bin/shellcheck")
            task.arguments = [
                "-f", "gcc",  // GCC-style output with line numbers
                "-S", "warning",  // Show warnings and above
                tempFile.path
            ]

            let outputPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = outputPipe

            try task.run()
            task.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                // Parse shellcheck output
                await MainActor.run {
                    parseShellcheckOutput(output, originalURL: originalURL)
                }
            }
        } catch {
            // Silently fail if shellcheck isn't available or has issues
            return
        }
    }

    /// Parse shellcheck output and log issues
    private func parseShellcheckOutput(_ output: String, originalURL: URL?) {
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            guard !line.isEmpty else { continue }

            // Parse format: file:line:column: level: message [SCxxxx]
            let components = line.components(separatedBy: ":")
            if components.count >= 4 {
                if let lineNum = Int(components[1].trimmingCharacters(in: .whitespaces)) {
                    let level = components[3].trimmingCharacters(in: .whitespaces)
                    let message = components.dropFirst(4).joined(separator: ":").trimmingCharacters(in: .whitespaces)

                    if level == "error" {
                        DebugLogger.shared.error(
                            "Line \(lineNum): \(message)",
                            category: "Shellcheck"
                        )
                    } else if level == "warning" {
                        DebugLogger.shared.warning(
                            "Line \(lineNum): \(message)",
                            category: "Shellcheck"
                        )
                    }
                }
            }
        }
    }

    // MARK: - Enhanced Error Analysis

    /// Analyze error and provide actionable suggestions
    private static func analyzeError(_ errorMessage: String, scriptURL: URL, originalURL: URL?) -> String {
        var analysis = ""
        let fileName = originalURL?.lastPathComponent ?? scriptURL.lastPathComponent

        // Common error patterns and suggestions
        if errorMessage.contains("command not found") {
            if let command = errorMessage.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) {
                analysis = """
                💡 How to fix:
                • Check if '\(command)' is installed: which \(command)
                • Install if missing: brew install \(command)
                • Verify the command name spelling
                """
            }
        } else if errorMessage.contains("Permission denied") {
            analysis = """
            💡 How to fix:
            • Check file permissions: ls -la [file]
            • Ensure you have read/write access
            • Script may need elevated permissions
            """
        } else if errorMessage.contains("No such file or directory") {
            analysis = """
            💡 How to fix:
            • Verify all file paths in your script
            • Use absolute paths or check working directory
            • Ensure files exist before accessing them
            """
        } else if errorMessage.contains("syntax error") {
            analysis = """
            💡 How to fix:
            • Check for matching quotes, brackets, parentheses
            • Look for unclosed strings or heredocs
            • Run: shellcheck \(fileName)
            """
        } else if errorMessage.contains("unbound variable") {
            analysis = """
            💡 How to fix:
            • Initialize the variable before using it
            • Use ${var:-default} for default values
            • Check for typos in variable names
            """
        }

        return analysis
    }
}
