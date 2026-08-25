// MessagingProtocol.swift
// Tabby
//
// Defines the JSON messaging protocol between the macOS app and browser extensions.
// All messages are encoded/decoded using these types.

import Foundation

// MARK: - Inbound Messages (Extension → macOS App)

/// Top-level inbound message envelope.
/// The extension sends JSON with a "type" field; we decode based on that.
nonisolated struct InboundMessage: Codable, Sendable {
    let type: String
    let browser: String?
    let tabs: [TabInfo]?
}

/// Tab information as sent by the browser extension.
/// This is the wire format; it gets converted to BrowserTab for internal use.
nonisolated struct TabInfo: Codable, Sendable {
    let tabId: Int
    let windowId: Int
    let title: String
    let url: String
    let favicon: String?
}

// MARK: - Outbound Messages (macOS App → Extension)

/// Command to activate a specific tab in the browser.
nonisolated struct ActivateTabCommand: Codable, Sendable {
    let type: String = "activateTab"
    let tabId: Int
    let windowId: Int

    enum CodingKeys: String, CodingKey {
        case type, tabId, windowId
    }
}

/// Command to request a full tab enumeration from the extension.
nonisolated struct RequestTabsCommand: Codable, Sendable {
    let type: String = "requestTabs"

    enum CodingKeys: String, CodingKey {
        case type
    }
}

/// Command to close a specific tab in the browser.
nonisolated struct CloseTabCommand: Codable, Sendable {
    let type: String = "closeTab"
    let tabId: Int
    let windowId: Int

    enum CodingKeys: String, CodingKey {
        case type, tabId, windowId
    }
}

/// Command to close all tabs for a browser.
nonisolated struct CloseAllTabsCommand: Codable, Sendable {
    let type: String = "closeAllTabs"

    enum CodingKeys: String, CodingKey {
        case type
    }
}

// MARK: - Message Encoding Helpers

/// Encodes a message to JSON Data.
/// Native Messaging protocol requires a 4-byte length prefix followed by JSON.
nonisolated enum MessageEncoder {

    /// Encode a Codable value to JSON Data (no length prefix).
    static func encodeJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    /// Encode a Codable value with the Native Messaging 4-byte length prefix.
    /// Format: [4 bytes little-endian UInt32 length][JSON bytes]
    static func encodeNativeMessage<T: Encodable>(_ value: T) throws -> Data {
        let jsonData = try encodeJSON(value)
        var length = UInt32(jsonData.count).littleEndian
        var output = Data(bytes: &length, count: 4)
        output.append(jsonData)
        return output
    }
}

// MARK: - Message Decoding Helpers

nonisolated enum MessageDecoder {

    /// Decode a JSON message from raw Data.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    /// Read a single Native Messaging frame from a FileHandle.
    /// Returns nil if the pipe is closed (EOF).
    /// Format: [4 bytes little-endian UInt32 length][JSON bytes]
    static func readNativeMessage(from fileHandle: FileHandle) -> Data? {
        // Read the 4-byte length prefix
        let lengthData = fileHandle.readData(ofLength: 4)
        guard lengthData.count == 4 else {
            return nil // EOF or broken pipe
        }

        let length = lengthData.withUnsafeBytes { ptr in
            ptr.load(as: UInt32.self).littleEndian
        }

        guard length > 0, length < 10_000_000 else {
            // Sanity check: reject messages larger than 10 MB
            return nil
        }

        // Read the JSON payload
        let jsonData = fileHandle.readData(ofLength: Int(length))
        guard jsonData.count == Int(length) else {
            return nil // Incomplete read
        }

        return jsonData
    }
}
