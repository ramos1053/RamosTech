//
//  ShellExecutor.swift
//  Nimbus-Swift
//

import Foundation
import Security

enum ShellError: Error, LocalizedError {
    case commandFailed(Int32, String)
    case authorizationFailed

    var errorDescription: String? {
        switch self {
        case .commandFailed(let code, let output):
            return "Command failed with exit code \(code): \(output)"
        case .authorizationFailed:
            return "Authorization failed or was cancelled"
        }
    }
}

class ShellExecutor {
    // Execute a shell command without admin privileges
    func execute(command: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let pipe = Pipe()
            let errorPipe = Pipe()

            task.standardOutput = pipe
            task.standardError = errorPipe
            task.arguments = ["-c", command]
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.standardInput = nil

            do {
                try task.run()

                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                if task.terminationStatus == 0 {
                    continuation.resume(returning: output.isEmpty ? "Command executed successfully" : output)
                } else {
                    let fullError = errorOutput.isEmpty ? output : errorOutput
                    continuation.resume(throwing: ShellError.commandFailed(task.terminationStatus, fullError))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // Execute a shell command with admin privileges using osascript
    func executeWithPrivileges(command: String) async throws -> String {
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = """
        do shell script "\(escapedCommand)" with administrator privileges
        """

        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let pipe = Pipe()

            task.standardOutput = pipe
            task.arguments = ["-e", appleScript]
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if task.terminationStatus == 0 {
                    continuation.resume(returning: output.isEmpty ? "Command executed successfully" : output)
                } else {
                    continuation.resume(throwing: ShellError.authorizationFailed)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
