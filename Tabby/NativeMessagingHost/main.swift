// TabbyHost.swift
//
// Native Messaging Host helper binary for Tabby.
//
// This binary is launched by Chrome or Edge when the browser extension
// calls connectNative("com.tabby.native_host"). The browser communicates with
// this binary via stdin/stdout using the Native Messaging protocol:
//
//   - Messages are framed with a 4-byte little-endian length prefix
//   - The payload is JSON
//
// This helper acts as a bridge:
//   1. Reads messages from the browser extension (via stdin)
//   2. Forwards them to the Tabby macOS app (via a Unix domain socket)
//   3. Reads responses from the Tabby app
//   4. Forwards them back to the browser extension (via stdout)
//
// The browser is identified via the --browser flag, which is set by the
// wrapper shell script created during extension installation.
//
// Usage (invoked by wrapper scripts, not directly):
//   TabbyHost --browser chrome
//   TabbyHost --browser edge

import Foundation
import Darwin

// MARK: - Configuration

/// Determine which browser launched us from the command line arguments.
/// The wrapper shell script (created by ExtensionInstaller) passes --browser <name>.
func determineBrowser() -> String {
    let args = CommandLine.arguments

    // Check for --browser flag (set by wrapper scripts created during install)
    if let idx = args.firstIndex(of: "--browser"), idx + 1 < args.count {
        return args[idx + 1]
    }

    // Fallback: check if the executable name hints at the browser
    let execName = (args.first ?? "").components(separatedBy: "/").last ?? ""
    if execName.lowercased().contains("chrome") { return "chrome" }
    if execName.lowercased().contains("edge") { return "edge" }

    // Last resort: check for Chrome/Edge extension origin passed as argument
    for arg in args where arg.hasPrefix("chrome-extension://") {
        return "chromium"
    }

    return "unknown"
}

// MARK: - Unix Domain Socket Client

/// Connects to the Tabby macOS app's Unix domain socket.
class SocketClient {
    let socketPath: String
    var socketFD: Int32 = -1

    init(socketPath: String) {
        self.socketPath = socketPath
    }

    /// Connect to the Unix domain socket.
    /// Returns true on success, false on failure.
    func connect() -> Bool {
        socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketFD >= 0 else {
            logError("Failed to create socket: errno=\(errno)")
            return false
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { sunPathPtr in
            let rawPtr = UnsafeMutableRawPointer(sunPathPtr)
            let bound = rawPtr.assumingMemoryBound(to: CChar.self)
            for (i, byte) in pathBytes.enumerated() {
                bound[i] = byte
            }
        }

        let result = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.connect(socketFD, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else {
            logError("Failed to connect to socket at \(socketPath): errno=\(errno)")
            Darwin.close(socketFD)
            socketFD = -1
            return false
        }

        return true
    }

    /// Send a length-prefixed message to the socket.
    func send(data: Data) {
        guard socketFD >= 0 else { return }
        var length = UInt32(data.count).littleEndian
        let lengthData = Data(bytes: &length, count: 4)

        _ = lengthData.withUnsafeBytes { ptr in
            Darwin.write(socketFD, ptr.baseAddress!, 4)
        }
        _ = data.withUnsafeBytes { ptr in
            Darwin.write(socketFD, ptr.baseAddress!, data.count)
        }
    }

    /// Read a length-prefixed message from the socket.
    /// Returns nil on error or EOF.
    func receive() -> Data? {
        guard socketFD >= 0 else { return nil }

        var lengthBytes = [UInt8](repeating: 0, count: 4)
        let n = Darwin.read(socketFD, &lengthBytes, 4)
        guard n == 4 else { return nil }

        let length = UInt32(lengthBytes[0])
            | (UInt32(lengthBytes[1]) << 8)
            | (UInt32(lengthBytes[2]) << 16)
            | (UInt32(lengthBytes[3]) << 24)

        guard length > 0, length < 10_000_000 else { return nil }

        var jsonBytes = [UInt8](repeating: 0, count: Int(length))
        var totalRead = 0
        while totalRead < Int(length) {
            let bytesRead = Darwin.read(socketFD, &jsonBytes[totalRead], Int(length) - totalRead)
            if bytesRead <= 0 { return nil }
            totalRead += bytesRead
        }

        return Data(jsonBytes)
    }

    /// Disconnect from the socket.
    func disconnect() {
        if socketFD >= 0 {
            Darwin.close(socketFD)
            socketFD = -1
        }
    }
}

// MARK: - Native Messaging I/O

/// Read a single Native Messaging frame from stdin.
/// Returns nil on EOF.
func readFromStdin() -> Data? {
    // Read 4-byte length prefix from stdin
    var lengthBytes = [UInt8](repeating: 0, count: 4)
    let n = fread(&lengthBytes, 1, 4, stdin)
    guard n == 4 else {
        return nil // EOF
    }

    let length = UInt32(lengthBytes[0])
        | (UInt32(lengthBytes[1]) << 8)
        | (UInt32(lengthBytes[2]) << 16)
        | (UInt32(lengthBytes[3]) << 24)

    guard length > 0, length < 10_000_000 else {
        logError("Invalid message length from stdin: \(length)")
        return nil
    }

    // Read the JSON payload
    var jsonBytes = [UInt8](repeating: 0, count: Int(length))
    let bytesRead = fread(&jsonBytes, 1, Int(length), stdin)
    guard bytesRead == Int(length) else {
        logError("Incomplete read from stdin: got \(bytesRead), expected \(length)")
        return nil
    }

    return Data(jsonBytes)
}

/// Write a Native Messaging frame to stdout.
func writeToStdout(_ data: Data) {
    var length = UInt32(data.count).littleEndian
    fwrite(&length, 4, 1, stdout)
    _ = data.withUnsafeBytes { ptr in
        fwrite(ptr.baseAddress!, 1, data.count, stdout)
    }
    fflush(stdout)
}

// MARK: - Logging

/// Log errors to stderr (not stdout, which is reserved for Native Messaging).
func logError(_ message: String) {
    let msg = "[TabbyHost] \(message)\n"
    fputs(msg, stderr)
}

func logInfo(_ message: String) {
    let msg = "[TabbyHost] \(message)\n"
    fputs(msg, stderr)
}

// MARK: - Main

let browser = determineBrowser()
let socketPath = NSTemporaryDirectory() + "tabby-\(browser).sock"

logInfo("Started for browser: \(browser)")
logInfo("Socket path: \(socketPath)")

// Connect to the Tabby app's Unix domain socket
let client = SocketClient(socketPath: socketPath)
var connected = false

// Retry connection a few times
for attempt in 1...5 {
    if client.connect() {
        connected = true
        logInfo("Connected to Tabby app (attempt \(attempt))")
        break
    }
    logError("Connection attempt \(attempt) failed, retrying in 1s...")
    Thread.sleep(forTimeInterval: 1.0)
}

guard connected else {
    logError("Failed to connect to Tabby app after 5 attempts. Exiting.")
    exit(1)
}

// Start a thread to read responses from the Tabby app and forward to stdout
let responseThread = Thread {
    while true {
        guard let data = client.receive() else {
            logError("Lost connection to Tabby app")
            exit(1)
        }
        writeToStdout(data)
    }
}
responseThread.qualityOfService = .userInitiated
responseThread.start()

// Main loop: read from stdin (browser) and forward to Tabby app
while true {
    guard let data = readFromStdin() else {
        logInfo("stdin closed (browser disconnected)")
        client.disconnect()
        exit(0)
    }
    client.send(data: data)
}
