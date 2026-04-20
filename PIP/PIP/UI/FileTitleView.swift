import SwiftUI
import AppKit

/// Interactive file title view with path display and actions
struct FileTitleView: View {
    let documentManager: DocumentManager
    @State private var isRenaming: Bool = false
    @State private var showPathPopover: Bool = false
    @State private var newName: String = ""

    var displayName: String {
        documentManager.currentDocument?.displayName ?? "Untitled"
    }

    var filePath: String? {
        documentManager.currentDocument?.url.path
    }

    var fileIcon: String {
        if let doc = documentManager.currentDocument {
            return doc.isExecutable ? "terminal" : "doc.text"
        }
        return "doc.text"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: fileIcon)

            if isRenaming {
                TextField("File name", text: $newName, onCommit: {
                    renameFile()
                })
                .textFieldStyle(.plain)
                .frame(width: 200)
                .onAppear {
                    newName = displayName
                }
            } else {
                Button(action: {
                    if filePath != nil {
                        showPathPopover.toggle()
                    } else {
                        isRenaming = true
                    }
                }) {
                    Text(displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPathPopover, arrowEdge: .bottom) {
                    FilePathPopover(
                        filePath: filePath ?? "",
                        onCopyPath: copyPathToClipboard,
                        onOpenTerminal: openTerminalAtPath
                    )
                }
                .help(filePath != nil ? "Click to show file location" : "Click to rename file")
            }

            if documentManager.isModified {
                Text("•")
                    .foregroundColor(.secondary)
                Text("Edited")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if documentManager.currentDocument?.isRemote == true {
                Image(systemName: "network")
                    .foregroundColor(.blue)
                    .help("Network file")
            }
        }
    }

    private func renameFile() {
        isRenaming = false
        guard !newName.isEmpty,
              newName != displayName,
              let currentURL = documentManager.currentDocument?.url else {
            return
        }

        let directory = currentURL.deletingLastPathComponent()
        let newURL = directory.appendingPathComponent(newName)

        do {
            try FileManager.default.moveItem(at: currentURL, to: newURL)
            documentManager.currentDocument?.url = newURL
        } catch {
            print("Failed to rename file: \(error)")
        }
    }

    private func copyPathToClipboard() {
        guard let path = filePath else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(path, forType: .string)
        showPathPopover = false
    }

    private func openTerminalAtPath() {
        guard let path = filePath else { return }
        let directory = (path as NSString).deletingLastPathComponent

        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(directory)'"
        end tell
        """

        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
        showPathPopover = false
    }
}

/// Popover view showing file path and actions
struct FilePathPopover: View {
    let filePath: String
    let onCopyPath: () -> Void
    let onOpenTerminal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("File Location")
                    .font(.headline)

                Text(filePath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(spacing: 8) {
                Button(action: onCopyPath) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("Copy Path")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                Button(action: onOpenTerminal) {
                    HStack {
                        Image(systemName: "terminal")
                        Text("Open Terminal Here")
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .padding()
        .frame(width: 350)
    }
}

#Preview("File Title - Saved Document") {
    FileTitleViewPreview(isModified: false)
}

#Preview("File Title - Unsaved Document") {
    FileTitleViewPreview(isModified: true)
}

struct FileTitleViewPreview: View {
    let isModified: Bool
    @StateObject private var manager = DocumentManager()

    var body: some View {
        FileTitleView(documentManager: manager)
            .padding()
            .onAppear {
                manager.currentDocument = DocumentManager.DocumentInfo(
                    url: URL(fileURLWithPath: "/Users/test/script.sh"),
                    format: .shell,
                    encoding: .utf8,
                    isRemote: false
                )
                manager.isModified = isModified
            }
    }
}

#Preview("File Path Popover") {
    FilePathPopover(
        filePath: "/Users/test/Documents/Projects/MyScript.sh",
        onCopyPath: { print("Copy path") },
        onOpenTerminal: { print("Open terminal") }
    )
}
