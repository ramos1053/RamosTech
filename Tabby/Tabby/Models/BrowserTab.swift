// BrowserTab.swift
// Tabby
//
// Core model representing a single browser tab from any supported browser.
// This is the canonical data type used throughout the app for display and activation.

import Foundation

// MARK: - Browser Enum

/// Represents each supported browser.
/// Raw values match the "browser" field in the JSON messaging protocol.
nonisolated enum Browser: String, Codable, CaseIterable, Identifiable, Sendable {
    case chrome = "chrome"
    case edge = "edge"

    var id: String { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .chrome:  return "Google Chrome"
        case .edge:    return "Microsoft Edge"
        }
    }

    /// SF Symbol name for the browser icon (fallback when favicon is unavailable)
    var sfSymbolName: String {
        switch self {
        case .chrome:  return "globe"
        case .edge:    return "globe"
        }
    }

    /// The bundle identifier used to activate the browser via NSWorkspace
    var bundleIdentifier: String {
        switch self {
        case .chrome:  return "com.google.Chrome"
        case .edge:    return "com.microsoft.edgemac"
        }
    }
}

// MARK: - BrowserTab Model

/// Represents a single tab from a browser extension.
/// Conforms to Identifiable and Hashable so it can be used in SwiftUI lists and grids.
nonisolated struct BrowserTab: Identifiable, Hashable, Codable, Sendable {
    /// Unique identifier composed of browser + windowId + tabId
    var id: String {
        "\(browser.rawValue)-\(windowId)-\(tabId)"
    }

    /// Which browser this tab belongs to
    let browser: Browser

    /// The browser-assigned tab ID (used in activateTab commands)
    let tabId: Int

    /// The browser-assigned window ID (used in activateTab commands)
    let windowId: Int

    /// The page title
    let title: String

    /// The page URL
    let url: String

    /// Base64-encoded favicon data URI (e.g. "data:image/png;base64,...")
    /// May be nil if the browser didn't provide one.
    let favicon: String?

    /// Timestamp when this tab data was last received
    let lastUpdated: Date

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
        lhs.id == rhs.id
    }
}
