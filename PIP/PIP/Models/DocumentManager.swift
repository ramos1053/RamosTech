import Foundation
import AppKit
import SwiftUI

/// Manages document operations including save, save as, import, and export
@MainActor
final class DocumentManager: ObservableObject {

    @Published var currentDocument: DocumentInfo?
    @Published var isModified: Bool = false
    @Published var showingSavePanel: Bool = false
    @Published var showingOpenPanel: Bool = false

    private let formatHandler = FileFormatHandler()

    struct DocumentInfo {
        var url: URL
        var format: FileFormat
        var encoding: String.Encoding
        var isRemote: Bool

        var displayName: String {
            url.lastPathComponent
        }

        var isExecutable: Bool {
            format.isExecutable
        }
    }

    // MARK: - Open/Import

    func openDocument(completion: @escaping (Result<(String, DocumentInfo), Error>) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .plainText, .text, .shellScript, .commaSeparatedText, .data
        ]

        // Enable network browsing
        panel.treatsFilePackagesAsDirectories = false
        panel.canSelectHiddenExtension = true

        panel.begin { [weak self] response in
            guard let self = self else { return }

            if response == .OK, let url = panel.url {
                DebugLogger.shared.info("User selected file to open: \(url.path)", category: "FileOperations")
                Task {
                    do {
                        let result = try await self.importFile(from: url)
                        await MainActor.run {
                            DebugLogger.shared.info("Successfully opened file: \(url.lastPathComponent)", category: "FileOperations")
                            completion(.success(result))
                        }
                    } catch {
                        await MainActor.run {
                            DebugLogger.shared.error("Failed to open file \(url.lastPathComponent): \(error.localizedDescription)", category: "FileOperations")
                            completion(.failure(error))
                        }
                    }
                }
            } else {
                DebugLogger.shared.debug("User cancelled file open dialog", category: "FileOperations")
            }
        }
    }

    func importFile(from url: URL, encoding: String.Encoding? = nil) async throws -> (String, DocumentInfo) {
        // More robust check for remote/network volumes
        let isRemote: Bool
        if !url.isFileURL {
            isRemote = true
        } else if let resourceValues = try? url.resourceValues(forKeys: [.volumeIsLocalKey]),
                  let isLocal = resourceValues.volumeIsLocal {
            isRemote = !isLocal
        } else {
            // Fallback to path-based check
            isRemote = url.path.contains("/Volumes/")
        }

        let (content, detectedEncoding, format) = try await formatHandler.importFile(
            from: url,
            encoding: encoding
        )

        let docInfo = DocumentInfo(
            url: url,
            format: format,
            encoding: detectedEncoding,
            isRemote: isRemote
        )

        await MainActor.run {
            self.currentDocument = docInfo
            self.isModified = false
        }

        return (content, docInfo)
    }

    // MARK: - Save

    func save(content: String) async throws {
        guard let doc = currentDocument else {
            let error = NSError(domain: "DocumentManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No document to save"])
            DebugLogger.shared.error("Save failed: No current document", category: "FileOperations")
            throw error
        }

        DebugLogger.shared.info("Saving file: \(doc.url.lastPathComponent)", category: "FileOperations")

        do {
            try await formatHandler.exportFile(
                content: content,
                to: doc.url,
                format: doc.format,
                encoding: doc.encoding
            )

            await MainActor.run {
                self.isModified = false
            }

            DebugLogger.shared.info("Successfully saved file: \(doc.url.lastPathComponent)", category: "FileOperations")
        } catch {
            DebugLogger.shared.error("Failed to save file \(doc.url.lastPathComponent): \(error.localizedDescription)", category: "FileOperations")
            throw error
        }
    }

    func saveAs(content: String, completion: @escaping (Result<DocumentInfo, Error>) -> Void) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.showsTagField = true
        panel.allowedContentTypes = [.plainText, .text]

        // Set default filename based on current format
        let defaultFormat = currentDocument?.format ?? .plainText
        let defaultFilename = getDefaultFilename(for: defaultFormat)
        panel.nameFieldStringValue = currentDocument?.displayName ?? defaultFilename

        // Add accessory view for format and encoding selection
        let accessoryView = createSaveAccessoryView(panel: panel, currentFormat: defaultFormat)
        panel.accessoryView = accessoryView

        panel.begin { [weak self] response in
            guard let self = self else { return }

            if response == .OK, let url = panel.url {
                Task {
                    do {
                        // Get selected format and encoding from accessory view
                        let format = self.getSelectedFormat(from: accessoryView)
                        let encoding = self.getSelectedEncoding(from: accessoryView)

                        // Ensure the URL has the correct file extension
                        let correctedURL = self.ensureCorrectExtension(url: url, format: format, accessoryView: accessoryView)

                        try await self.formatHandler.exportFile(
                            content: content,
                            to: correctedURL,
                            format: format,
                            encoding: encoding
                        )

                        // More robust check for remote/network volumes
                        let isRemote: Bool
                        if !correctedURL.isFileURL {
                            isRemote = true
                        } else if let resourceValues = try? correctedURL.resourceValues(forKeys: [.volumeIsLocalKey]),
                                  let isLocal = resourceValues.volumeIsLocal {
                            isRemote = !isLocal
                        } else {
                            // Fallback to path-based check
                            isRemote = correctedURL.path.contains("/Volumes/")
                        }
                        let docInfo = DocumentInfo(
                            url: correctedURL,
                            format: format,
                            encoding: encoding,
                            isRemote: isRemote
                        )

                        await MainActor.run {
                            self.currentDocument = docInfo
                            self.isModified = false
                            completion(.success(docInfo))
                        }
                    } catch {
                        await MainActor.run {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
    }

    private func getDefaultFilename(for format: FileFormat) -> String {
        switch format {
        case .plainText:
            return "Untitled.txt"
        case .shell:
            return "Untitled.sh"
        case .bash:
            return "Untitled.bash"
        case .zsh:
            return "Untitled.zsh"
        case .python:
            return "Untitled.py"
        case .ruby:
            return "Untitled.rb"
        case .perl:
            return "Untitled.pl"
        case .javascript:
            return "Untitled.js"
        case .php:
            return "Untitled.php"
        }
    }

    private func ensureCorrectExtension(url: URL, format: FileFormat, accessoryView: NSView) -> URL {
        let baseURL = url.deletingPathExtension()
        let correctExtension: String

        if format == .shell {
            // Get the selected script extension from nested menu
            if let popup = accessoryView.subviews.first(where: { $0.identifier?.rawValue == "scriptExtPopup" }) as? NSPopUpButton {
                let index = popup.indexOfSelectedItem
                switch index {
                case 1: correctExtension = "sh"
                case 2: correctExtension = "bash"
                case 3: correctExtension = "zsh"
                case 5: correctExtension = "py"
                case 6: correctExtension = "rb"
                case 7: correctExtension = "pl"
                case 8: correctExtension = "js"
                case 9: correctExtension = "php"
                default: correctExtension = "sh"
                }
            } else {
                correctExtension = "sh"
            }
        } else {
            correctExtension = format.fileExtension
        }

        return baseURL.appendingPathExtension(correctExtension)
    }

    // MARK: - Export

    func exportAs(content: String, format: FileFormat, encoding: String.Encoding = .utf8) async throws {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "export.\(format.fileExtension)"

        let response = await panel.begin()

        if response == .OK, let url = panel.url {
            try await formatHandler.exportFile(
                content: content,
                to: url,
                format: format,
                encoding: encoding
            )
        }
    }

    // MARK: - Accessory Views

    private func createSaveAccessoryView(panel: NSSavePanel, currentFormat: FileFormat) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 110))

        // Format selection
        let formatLabel = NSTextField(labelWithString: "Format:")
        formatLabel.frame = NSRect(x: 0, y: 80, width: 100, height: 20)
        container.addSubview(formatLabel)

        let formatPopup = NSPopUpButton(frame: NSRect(x: 110, y: 75, width: 280, height: 25), pullsDown: false)
        formatPopup.identifier = NSUserInterfaceItemIdentifier("formatPopup")
        for format in FileFormat.allCases {
            formatPopup.addItem(withTitle: format.displayName)
        }
        // Select current format
        if let index = FileFormat.allCases.firstIndex(of: currentFormat) {
            formatPopup.selectItem(at: index)
        }
        container.addSubview(formatPopup)

        // Script extension selection (shown only for shell scripts)
        let scriptExtLabel = NSTextField(labelWithString: "Script Type:")
        scriptExtLabel.frame = NSRect(x: 0, y: 50, width: 100, height: 20)
        scriptExtLabel.identifier = NSUserInterfaceItemIdentifier("scriptExtLabel")
        scriptExtLabel.isHidden = currentFormat != .shell
        container.addSubview(scriptExtLabel)

        let scriptExtPopup = NSPopUpButton(frame: NSRect(x: 110, y: 45, width: 280, height: 25), pullsDown: false)
        scriptExtPopup.identifier = NSUserInterfaceItemIdentifier("scriptExtPopup")

        // Create nested menu structure for script types
        let menu = NSMenu()

        // Shell Scripts category
        let shellHeader = NSMenuItem()
        shellHeader.title = "Shell Scripts"
        shellHeader.isEnabled = false
        menu.addItem(shellHeader)

        menu.addItem(withTitle: "  Shell Script (.sh)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "  Bash Script (.bash)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "  Zsh Script (.zsh)", action: nil, keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        // Scripting Languages category
        let scriptingHeader = NSMenuItem()
        scriptingHeader.title = "Scripting Languages"
        scriptingHeader.isEnabled = false
        menu.addItem(scriptingHeader)

        menu.addItem(withTitle: "  Python (.py)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "  Ruby (.rb)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "  Perl (.pl)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "  JavaScript (.js)", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "  PHP (.php)", action: nil, keyEquivalent: "")

        scriptExtPopup.menu = menu
        scriptExtPopup.selectItem(at: 1) // Default to Shell Script (.sh)
        scriptExtPopup.isHidden = currentFormat != .shell
        container.addSubview(scriptExtPopup)

        // Encoding selection
        let encodingLabel = NSTextField(labelWithString: "Encoding:")
        encodingLabel.frame = NSRect(x: 0, y: 20, width: 100, height: 20)
        container.addSubview(encodingLabel)

        let encodingPopup = NSPopUpButton(frame: NSRect(x: 110, y: 15, width: 280, height: 25), pullsDown: false)
        encodingPopup.identifier = NSUserInterfaceItemIdentifier("encodingPopup")
        let encodings: [(String, String.Encoding)] = [
            ("UTF-8", .utf8),
            ("UTF-16", .utf16),
            ("UTF-16 Big Endian", .utf16BigEndian),
            ("UTF-16 Little Endian", .utf16LittleEndian),
            ("UTF-32", .utf32),
            ("UTF-32 Big Endian", .utf32BigEndian),
            ("UTF-32 Little Endian", .utf32LittleEndian),
            ("ASCII", .ascii),
            ("ISO Latin 1", .isoLatin1),
            ("Mac OS Roman", .macOSRoman),
            ("Windows CP-1252", .windowsCP1252)
        ]
        for (name, _) in encodings {
            encodingPopup.addItem(withTitle: name)
        }
        container.addSubview(encodingPopup)

        // Create helper for handling actions
        let helper = SavePanelHelper()
        helper.panel = panel
        helper.formatPopup = formatPopup
        helper.scriptExtLabel = scriptExtLabel
        helper.scriptExtPopup = scriptExtPopup

        // Store helper as associated object to keep it alive
        objc_setAssociatedObject(panel, "savePanelHelper", helper, .OBJC_ASSOCIATION_RETAIN)

        // Add action to format popup
        formatPopup.target = helper
        formatPopup.action = #selector(SavePanelHelper.formatChanged(_:))

        // Add action to script extension popup
        scriptExtPopup.target = helper
        scriptExtPopup.action = #selector(SavePanelHelper.scriptExtensionChanged(_:))

        return container
    }

    private func getSelectedFormat(from view: NSView) -> FileFormat {
        if let popup = view.subviews.first(where: { $0.identifier?.rawValue == "formatPopup" }) as? NSPopUpButton {
            let index = popup.indexOfSelectedItem
            if index >= 0 && index < FileFormat.allCases.count {
                return FileFormat.allCases[index]
            }
        }
        return currentDocument?.format ?? .plainText
    }

    private func getSelectedEncoding(from view: NSView) -> String.Encoding {
        if let popup = view.subviews.first(where: { $0.identifier?.rawValue == "encodingPopup" }) as? NSPopUpButton {
            let encodings: [String.Encoding] = [
                .utf8, .utf16, .utf16BigEndian, .utf16LittleEndian,
                .utf32, .utf32BigEndian, .utf32LittleEndian,
                .ascii, .isoLatin1, .macOSRoman, .windowsCP1252
            ]
            let index = popup.indexOfSelectedItem
            if index >= 0 && index < encodings.count {
                return encodings[index]
            }
        }
        return currentDocument?.encoding ?? .utf8
    }

    // MARK: - Network Support

    func browseNetworkLocation(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        // Enable network browsing
        panel.treatsFilePackagesAsDirectories = false

        panel.begin { response in
            if response == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }
}

// MARK: - Save Panel Helper

class SavePanelHelper: NSObject {
    weak var panel: NSSavePanel?
    weak var formatPopup: NSPopUpButton?
    weak var scriptExtLabel: NSTextField?
    weak var scriptExtPopup: NSPopUpButton?

    @objc func formatChanged(_ sender: NSPopUpButton) {
        guard let panel = panel,
              let scriptExtLabel = scriptExtLabel,
              let scriptExtPopup = scriptExtPopup else {
            return
        }

        let selectedIndex = sender.indexOfSelectedItem
        guard selectedIndex >= 0 && selectedIndex < FileFormat.allCases.count else { return }

        let format = FileFormat.allCases[selectedIndex]

        // Show/hide script extension controls
        let isScript = format == .shell
        scriptExtLabel.isHidden = !isScript
        scriptExtPopup.isHidden = !isScript

        // Update filename based on format
        let currentName = panel.nameFieldStringValue
        let nameWithoutExt = (currentName as NSString).deletingPathExtension
        let newExtension: String

        if isScript {
            // Get selected script extension from nested menu
            let scriptExtIndex = scriptExtPopup.indexOfSelectedItem
            switch scriptExtIndex {
            case 1: newExtension = "sh"
            case 2: newExtension = "bash"
            case 3: newExtension = "zsh"
            case 5: newExtension = "py"
            case 6: newExtension = "rb"
            case 7: newExtension = "pl"
            case 8: newExtension = "js"
            case 9: newExtension = "php"
            default: newExtension = "sh"
            }
        } else {
            newExtension = format.fileExtension
        }

        panel.nameFieldStringValue = "\(nameWithoutExt).\(newExtension)"
    }

    @objc func scriptExtensionChanged(_ sender: NSPopUpButton) {
        guard let panel = panel else { return }

        let selectedIndex = sender.indexOfSelectedItem
        let newExtension: String

        switch selectedIndex {
        case 1: newExtension = "sh"
        case 2: newExtension = "bash"
        case 3: newExtension = "zsh"
        case 5: newExtension = "py"
        case 6: newExtension = "rb"
        case 7: newExtension = "pl"
        case 8: newExtension = "js"
        case 9: newExtension = "php"
        default: return
        }

        let currentName = panel.nameFieldStringValue
        let nameWithoutExt = (currentName as NSString).deletingPathExtension

        panel.nameFieldStringValue = "\(nameWithoutExt).\(newExtension)"
    }
}
