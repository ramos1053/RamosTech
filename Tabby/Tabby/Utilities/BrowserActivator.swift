// BrowserActivator.swift
// Tabby
//
// Utility to bring a browser window to the foreground using NSWorkspace.
// This is used when the user clicks a tab tile — we first send the activateTab
// command to the extension, then bring the browser app to the front.

import AppKit

// MARK: - BrowserActivator

/// Brings a browser application to the foreground.
enum BrowserActivator {

    /// Activate (bring to front) the specified browser application.
    /// Uses NSWorkspace to launch/activate by bundle identifier.
    static func activate(browser: Browser) {
        let bundleId = browser.bundleIdentifier

        // Try to find a running instance first
        if let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleId
        ).first {
            app.activate(options: [.activateAllWindows])
        } else {
            // If not running, launch it
            if let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleId
            ) {
                NSWorkspace.shared.openApplication(
                    at: url,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            }
        }
    }
}
