// ExtensionInstaller.swift
// Tabby
//
// Handles installing and uninstalling browser extensions for Chrome and Edge.
// Each browser uses a different directory for Native Messaging host manifests.
// The actual extension files are bundled inside the app's Resources directory.
//
// Installation involves:
// 1. Creating a wrapper shell script that calls TabbyHost with --browser <name>
// 2. Writing a Native Messaging host manifest JSON pointing to the wrapper script
// 3. Copying extension files to a known location for the user to load in the browser
//
// Uninstallation reverses these steps.

import Foundation

// MARK: - ExtensionInstaller

/// Installs and uninstalls browser extensions and their Native Messaging host manifests.
nonisolated final class ExtensionInstaller {

    // MARK: - Constants

    /// The Native Messaging host name (must match what the extension uses in connectNative())
    static let hostName = "com.tabby.native_host"

    /// The allowed extension IDs for each browser (derived from the key in each manifest.json)
    static let chromeExtensionOrigin = "chrome-extension://edbckfbllpbcdcffgjjlgpkbfheinoai/"
    static let edgeExtensionOrigin = "chrome-extension://jpagelodiceclpnnkdgghlmgegfmcnbm/"

    // MARK: - Directory Paths

    /// App Support base directory for Tabby's installed files
    static var tabbyAppSupportDir: String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!.path
        return "\(appSupport)/Tabby"
    }

    /// Returns the Native Messaging host manifest directory for a given browser.
    static func nativeMessagingHostDir(for browser: Browser) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch browser {
        case .chrome:
            return "\(home)/Library/Application Support/Google/Chrome/NativeMessagingHosts"
        case .edge:
            return "\(home)/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
        }
    }

    /// Returns the path to the Native Messaging host manifest file for a given browser.
    static func manifestPath(for browser: Browser) -> String {
        let dir = nativeMessagingHostDir(for: browser)
        return "\(dir)/\(hostName).json"
    }

    /// Returns the path to the TabbyHost binary inside the app bundle.
    static var hostBinaryPath: String {
        let appPath = Bundle.main.bundlePath
        return "\(appPath)/Contents/MacOS/TabbyHost"
    }

    /// Returns the path where the wrapper shell script is installed for a given browser.
    /// The native messaging host manifest points to this script.
    static func wrapperScriptPath(for browser: Browser) -> String {
        return "\(tabbyAppSupportDir)/bin/tabby-\(browser.rawValue)-host.sh"
    }

    /// Returns the path where extension files are installed for a given browser.
    static func extensionInstallDir(for browser: Browser) -> String {
        return "\(tabbyAppSupportDir)/Extensions/\(browser.rawValue)"
    }

    // MARK: - Installation

    /// Install the extension and Native Messaging host for a specific browser.
    /// - Parameter browser: The target browser
    /// - Throws: If file operations fail
    static func install(for browser: Browser) throws {
        let fm = FileManager.default

        // 1. Create the bin directory for wrapper scripts
        let binDir = "\(tabbyAppSupportDir)/bin"
        if !fm.fileExists(atPath: binDir) {
            try fm.createDirectory(atPath: binDir, withIntermediateDirectories: true)
        }

        // 2. Create the Native Messaging host directory if it doesn't exist
        let hostDir = nativeMessagingHostDir(for: browser)
        if !fm.fileExists(atPath: hostDir) {
            try fm.createDirectory(atPath: hostDir, withIntermediateDirectories: true)
        }

        // 3. Create the extension install directory
        let extDir = extensionInstallDir(for: browser)
        if !fm.fileExists(atPath: extDir) {
            try fm.createDirectory(atPath: extDir, withIntermediateDirectories: true)
        }

        // 4. Copy extension files from bundle to install directory
        try copyExtensionFiles(for: browser, to: extDir)

        // 5. Write the wrapper shell script
        let wrapperPath = wrapperScriptPath(for: browser)
        let wrapperContent = generateWrapperScript(for: browser)
        try wrapperContent.write(toFile: wrapperPath, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperPath)

        // 6. Write the Native Messaging host manifest (pointing to the wrapper script)
        let manifest = generateHostManifest(for: browser)
        let manifestFile = manifestPath(for: browser)
        try manifest.write(toFile: manifestFile, atomically: true, encoding: .utf8)

        print("[ExtensionInstaller] Installed \(browser.displayName) extension")
        print("  Manifest: \(manifestFile)")
        print("  Wrapper script: \(wrapperPath)")
        print("  Extension files: \(extDir)")
        print("  Host binary: \(hostBinaryPath)")
    }

    /// Uninstall the extension and Native Messaging host for a specific browser.
    static func uninstall(for browser: Browser) {
        let fm = FileManager.default

        // Remove the manifest, wrapper script, and extension files
        try? fm.removeItem(atPath: manifestPath(for: browser))
        try? fm.removeItem(atPath: wrapperScriptPath(for: browser))
        try? fm.removeItem(atPath: extensionInstallDir(for: browser))

        print("[ExtensionInstaller] Uninstalled \(browser.displayName) extension")
    }

    /// Check if the extension is currently installed for a browser.
    static func isInstalled(for browser: Browser) -> Bool {
        return FileManager.default.fileExists(atPath: manifestPath(for: browser))
    }

    /// Re-copy extension files from the app bundle for all installed browsers.
    /// Call this on app launch to ensure deployed extensions stay up-to-date
    /// with the latest code bundled in the app.
    static func updateInstalledExtensions() {
        for browser in Browser.allCases {
            guard isInstalled(for: browser) else { continue }
            let extDir = extensionInstallDir(for: browser)
            do {
                try copyExtensionFiles(for: browser, to: extDir)
                print("[ExtensionInstaller] Updated \(browser.displayName) extension files")
            } catch {
                print("[ExtensionInstaller] Failed to update \(browser.displayName): \(error)")
            }
        }
    }

    // MARK: - Private Helpers

    /// Generate a wrapper shell script that invokes TabbyHost with the --browser flag.
    private static func generateWrapperScript(for browser: Browser) -> String {
        return """
        #!/bin/bash
        # Tabby Native Messaging Host wrapper for \(browser.displayName)
        # Invoked by the browser's native messaging system.
        exec "\(hostBinaryPath)" --browser \(browser.rawValue) "$@"
        """
    }

    /// Generate the Native Messaging host manifest JSON for a browser.
    private static func generateHostManifest(for browser: Browser) -> String {
        let wrapperPath = wrapperScriptPath(for: browser)

        switch browser {
        case .chrome:
            return """
            {
              "name": "\(hostName)",
              "description": "Tabby Native Messaging Host - Tab enumeration for macOS",
              "path": "\(wrapperPath)",
              "type": "stdio",
              "allowed_origins": [
                "\(chromeExtensionOrigin)"
              ]
            }
            """
        case .edge:
            return """
            {
              "name": "\(hostName)",
              "description": "Tabby Native Messaging Host - Tab enumeration for macOS",
              "path": "\(wrapperPath)",
              "type": "stdio",
              "allowed_origins": [
                "\(edgeExtensionOrigin)"
              ]
            }
            """
        }
    }

    /// Copy extension files from the app bundle to the install directory.
    private static func copyExtensionFiles(for browser: Browser, to destDir: String) throws {
        let fm = FileManager.default

        let bundleExtDir: String
        switch browser {
        case .chrome:  bundleExtDir = "Chrome"
        case .edge:    bundleExtDir = "Edge"
        }

        // Look in the app bundle's Resources/Extensions/ directory
        let resourcePath = Bundle.main.resourcePath ?? ""
        let sourceDir = "\(resourcePath)/Extensions/\(bundleExtDir)"

        if fm.fileExists(atPath: sourceDir) {
            if fm.fileExists(atPath: destDir) {
                try fm.removeItem(atPath: destDir)
            }
            try fm.copyItem(atPath: sourceDir, toPath: destDir)
        } else {
            print("[ExtensionInstaller] Extension files not found at \(sourceDir)")
        }
    }
}
