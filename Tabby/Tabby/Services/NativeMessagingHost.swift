// NativeMessagingHost.swift
// Tabby
//
// Implements the Native Messaging host that communicates with Chrome and Edge
// browser extensions. Each browser extension connects via stdin/stdout to a separate
// instance of the native messaging host helper binary.
//
// This service manages:
// - Launching/monitoring the native messaging host helper processes
// - Receiving tab update messages from extensions
// - Sending activateTab commands to extensions
//
// The native messaging host helper binary (TabbyHost) is bundled inside the app.
// When installed, a manifest JSON file points the browser to this binary.

import Foundation
import Combine

// MARK: - NativeMessagingHost

/// Manages communication with Chrome/Edge extensions via Native Messaging.
/// Each browser gets its own connection (stdin/stdout pipe pair).
@MainActor
final class NativeMessagingHost: ObservableObject {

    // MARK: - Published State

    /// All tabs received from all native-messaging-based browsers, keyed by browser
    @Published var tabsByBrowser: [Browser: [BrowserTab]] = [
        .chrome: [],
        .edge: []
    ]

    // MARK: - Private Properties

    /// Active connections keyed by browser
    private var connections: [Browser: NativeMessagingConnection] = [:]

    // MARK: - Public API

    /// Start listening for connections from a specific browser's extension.
    func startListening(for browser: Browser) {
        if connections[browser] != nil {
            return // Already listening
        }

        let connection = NativeMessagingConnection(browser: browser)
        connection.onTabsUpdated = { [weak self] tabs in
            Task { @MainActor [weak self] in
                self?.tabsByBrowser[browser] = tabs
            }
        }
        connections[browser] = connection
        connection.startListening()
    }

    /// Stop listening for a specific browser.
    func stopListening(for browser: Browser) {
        connections[browser]?.stop()
        connections.removeValue(forKey: browser)
        tabsByBrowser[browser] = []
    }

    /// Send an "activateTab" command to the appropriate browser's extension.
    func activateTab(_ tab: BrowserTab) {
        let command = ActivateTabCommand(tabId: tab.tabId, windowId: tab.windowId)
        connections[tab.browser]?.send(command: command)

        // Also bring the browser to the foreground
        BrowserActivator.activate(browser: tab.browser)
    }

    /// Request a fresh tab enumeration from a specific browser's extension.
    func requestTabs(from browser: Browser) {
        let command = RequestTabsCommand()
        connections[browser]?.sendGeneric(command)
    }

    /// Close a specific tab in the browser.
    func closeTab(_ tab: BrowserTab) {
        let command = CloseTabCommand(tabId: tab.tabId, windowId: tab.windowId)
        connections[tab.browser]?.sendGeneric(command)
    }

    /// Close all tabs for a specific browser.
    func closeAllTabs(for browser: Browser) {
        let command = CloseAllTabsCommand()
        connections[browser]?.sendGeneric(command)
    }
}

// MARK: - NativeMessagingConnection

/// Represents a single Native Messaging connection to one browser extension.
/// The browser launches the TabbyHost binary, which communicates via stdin/stdout.
/// This class manages the Unix domain socket that the host binary connects to.
nonisolated final class NativeMessagingConnection: @unchecked Sendable {

    let browser: Browser

    /// Callback when tabs are updated — called on arbitrary queue, caller must dispatch to main
    var onTabsUpdated: (([BrowserTab]) -> Void)?

    /// The Unix domain socket server for this browser
    private var socketServer: TabbySocketServer?

    /// Serializes access to mutable state
    private let lock = NSLock()

    /// Path to the Unix domain socket
    private var socketPath: String {
        let tmpDir = NSTemporaryDirectory()
        return "\(tmpDir)tabby-\(browser.rawValue).sock"
    }

    init(browser: Browser) {
        self.browser = browser
    }

    /// Start listening on the Unix domain socket.
    func startListening() {
        // Clean up any stale socket file
        try? FileManager.default.removeItem(atPath: socketPath)

        let server = TabbySocketServer(
            socketPath: socketPath,
            browser: browser,
            onTabsUpdated: { [weak self] tabs in
                self?.lock.lock()
                let callback = self?.onTabsUpdated
                self?.lock.unlock()
                callback?(tabs)
            }
        )
        lock.lock()
        socketServer = server
        lock.unlock()
        server.start()
    }

    /// Send an activateTab command.
    func send(command: ActivateTabCommand) {
        lock.lock()
        let server = socketServer
        lock.unlock()
        server?.sendToClient(command)
    }

    /// Send a generic Encodable command.
    func sendGeneric<T: Encodable>(_ command: T) {
        lock.lock()
        let server = socketServer
        lock.unlock()
        server?.sendToClient(command)
    }

    /// Stop the connection.
    func stop() {
        lock.lock()
        let server = socketServer
        socketServer = nil
        lock.unlock()
        server?.stop()
        try? FileManager.default.removeItem(atPath: socketPath)
    }
}

// MARK: - TabbySocketServer

/// A simple Unix domain socket server that the TabbyHost helper connects to.
/// This bridges the Native Messaging stdin/stdout protocol to the macOS app.
///
/// All mutable state is accessed exclusively on `queue` (a serial dispatch queue).
nonisolated final class TabbySocketServer: @unchecked Sendable {

    private let socketPath: String
    private let browser: Browser
    private let onTabsUpdated: @Sendable ([BrowserTab]) -> Void

    // All mutable state below is accessed only on `queue`
    private var serverSocket: Int32 = -1
    private var clientSocket: Int32 = -1
    private var isRunning = false
    private var readSource: DispatchSourceRead?

    private let queue = DispatchQueue(label: "com.tabby.socket", qos: .userInitiated)

    init(socketPath: String, browser: Browser, onTabsUpdated: @escaping @Sendable ([BrowserTab]) -> Void) {
        self.socketPath = socketPath
        self.browser = browser
        self.onTabsUpdated = onTabsUpdated
    }

    func start() {
        queue.async { [self] in
            self.setupServer()
        }
    }

    func stop() {
        queue.sync { [self] in
            self.isRunning = false
            self.readSource?.cancel()
            self.readSource = nil
            if self.clientSocket >= 0 {
                close(self.clientSocket)
                self.clientSocket = -1
            }
            if self.serverSocket >= 0 {
                close(self.serverSocket)
                self.serverSocket = -1
            }
            unlink(self.socketPath)
        }
    }

    func sendToClient<T: Encodable>(_ message: T) {
        queue.async { [self] in
            guard self.clientSocket >= 0 else { return }
            do {
                let data = try MessageEncoder.encodeJSON(message)
                // Write 4-byte length prefix (little-endian) + JSON
                var length = UInt32(data.count).littleEndian
                let lengthData = Data(bytes: &length, count: 4)

                _ = lengthData.withUnsafeBytes { ptr in
                    Darwin.write(self.clientSocket, ptr.baseAddress!, 4)
                }
                _ = data.withUnsafeBytes { ptr in
                    Darwin.write(self.clientSocket, ptr.baseAddress!, data.count)
                }
            } catch {
                print("[TabbySocketServer] Failed to encode message: \(error)")
            }
        }
    }

    // MARK: - Private (all called on `queue`)

    private func setupServer() {
        // Create Unix domain socket
        serverSocket = socket(AF_UNIX, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("[TabbySocketServer] Failed to create socket: \(errno)")
            return
        }

        // Bind to socket path
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

        let bindResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindResult == 0 else {
            print("[TabbySocketServer] Failed to bind socket: \(errno)")
            close(serverSocket)
            serverSocket = -1
            return
        }

        // Listen for one connection
        guard listen(serverSocket, 1) == 0 else {
            print("[TabbySocketServer] Failed to listen: \(errno)")
            close(serverSocket)
            serverSocket = -1
            return
        }

        isRunning = true
        print("[TabbySocketServer] Listening on \(socketPath) for \(browser.displayName)")

        // Accept connections in a loop
        acceptLoop()
    }

    private func acceptLoop() {
        // Use a background thread for blocking accept() so we don't block the serial queue
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            guard self.isRunning else { return }

            var clientAddr = sockaddr_un()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_un>.size)

            let fd = withUnsafeMutablePointer(to: &clientAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    accept(self.serverSocket, sockaddrPtr, &clientAddrLen)
                }
            }

            guard fd >= 0 else {
                if self.isRunning {
                    print("[TabbySocketServer] Accept failed: \(errno)")
                }
                return
            }

            // Dispatch back to our serial queue to update state
            self.queue.async { [self] in
                print("[TabbySocketServer] Client connected for \(self.browser.displayName)")
                self.clientSocket = fd
                self.readFromClient()
            }
        }
    }

    private func readFromClient() {
        let source = DispatchSource.makeReadSource(fileDescriptor: clientSocket, queue: queue)
        source.setEventHandler { [self] in
            self.handleClientData()
        }
        source.setCancelHandler { [self] in
            if self.clientSocket >= 0 {
                close(self.clientSocket)
                self.clientSocket = -1
            }
        }
        readSource = source
        source.resume()
    }

    private func handleClientData() {
        // Read 4-byte length prefix
        var lengthBytes = [UInt8](repeating: 0, count: 4)
        let bytesRead = read(clientSocket, &lengthBytes, 4)

        guard bytesRead == 4 else {
            // Client disconnected
            print("[TabbySocketServer] Client disconnected for \(browser.displayName)")
            readSource?.cancel()
            readSource = nil
            // Re-accept
            if isRunning { acceptLoop() }
            return
        }

        let length = UInt32(lengthBytes[0])
            | (UInt32(lengthBytes[1]) << 8)
            | (UInt32(lengthBytes[2]) << 16)
            | (UInt32(lengthBytes[3]) << 24)

        guard length > 0, length < 10_000_000 else {
            print("[TabbySocketServer] Invalid message length: \(length)")
            return
        }

        // Read the JSON payload
        var jsonBytes = [UInt8](repeating: 0, count: Int(length))
        var totalRead = 0
        while totalRead < Int(length) {
            let n = read(clientSocket, &jsonBytes[totalRead], Int(length) - totalRead)
            if n <= 0 { break }
            totalRead += n
        }

        guard totalRead == Int(length) else {
            print("[TabbySocketServer] Incomplete message read")
            return
        }

        let data = Data(jsonBytes)
        processMessage(data)
    }

    private func processMessage(_ data: Data) {
        do {
            let message = try MessageDecoder.decode(InboundMessage.self, from: data)

            if message.type == "tabUpdate", let tabInfos = message.tabs {
                // Debug: check favicon data arriving from extensions
                for info in tabInfos.prefix(3) {
                    if let fav = info.favicon {
                        print("[TabbySocketServer] Tab '\(info.title.prefix(30))' favicon: \(fav.prefix(80))... (\(fav.count) chars)")
                    } else {
                        print("[TabbySocketServer] Tab '\(info.title.prefix(30))' favicon: nil")
                    }
                }

                let tabs = tabInfos.map { info in
                    BrowserTab(
                        browser: browser,
                        tabId: info.tabId,
                        windowId: info.windowId,
                        title: info.title,
                        url: info.url,
                        favicon: info.favicon,
                        lastUpdated: Date()
                    )
                }
                onTabsUpdated(tabs)
            }
        } catch {
            print("[TabbySocketServer] Failed to decode message: \(error)")
            if let str = String(data: data, encoding: .utf8) {
                print("[TabbySocketServer] Raw message: \(str.prefix(500))")
            }
        }
    }
}
