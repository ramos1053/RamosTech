import SwiftUI

struct ContentView: View {
    @StateObject private var textEngine = TextEngine()
    @StateObject private var documentManager = DocumentManager()
    @StateObject private var scriptExecutor = ScriptExecutor()
    @ObservedObject var preferences = AppPreferences.shared

    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        ZStack {
            // Window transparency controller
            WindowAccessor(opacity: $preferences.themeOpacity)

            VStack(spacing: 0) {
            // Toolbar
            HStack {
                // File info
                FileTitleView(documentManager: documentManager)

                Spacer()

                // Quick actions
                if documentManager.currentDocument?.isExecutable == true {
                    Button(action: runScript) {
                        Label("Run", systemImage: scriptExecutor.isRunning ? "stop.circle" : "play.circle")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(scriptExecutor.isRunning ? .red : .blue)
                }

                Button(action: openFile) {
                    if preferences.showToolbarLabels {
                        Label("Open", systemImage: "folder")
                    } else {
                        Image(systemName: "folder")
                    }
                }
                .help("Open File (⌘O)")

                Button(action: saveFile) {
                    if preferences.showToolbarLabels {
                        Label("Save", systemImage: "square.and.arrow.down")
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                .help("Save (⌘S)")
                .disabled(documentManager.currentDocument == nil)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Main editor
            EditorView(textEngine: textEngine)

            // Log viewer (when script is running or has output)
            if scriptExecutor.showLog {
                Divider()
                LogViewer(executor: scriptExecutor)
            }

            Divider()

            // Status bar
            HStack {
                Text("Line: \(textEngine.currentLine), Col: \(textEngine.currentColumn)")
                    .font(.caption)

                Spacer()

                if let doc = documentManager.currentDocument {
                    Text(doc.encoding.description)
                        .font(.caption)
                    Text("•")
                        .font(.caption)
                    Text(doc.format.displayName)
                        .font(.caption)
                    Text("•")
                        .font(.caption)
                }

                Text(textEngine.lineEnding.description)
                    .font(.caption)

                Text("•")
                    .font(.caption)

                Text("\(textEngine.text.count) chars")
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newDocument)) { _ in
            newDocument()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDocument)) { _ in
            openFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveDocument)) { _ in
            saveFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveDocumentAs)) { _ in
            saveFileAs()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportDocument)) { notification in
            if let format = notification.object as? FileFormat {
                exportAs(format: format)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .runScript)) { _ in
            runScript()
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopScript)) { _ in
            scriptExecutor.stopExecution()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearLog)) { _ in
            scriptExecutor.clearLog()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportLog)) { _ in
            scriptExecutor.saveLogToFile()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleLog)) { _ in
            scriptExecutor.showLog.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .convertLineEnding)) { notification in
            if let lineEnding = notification.object as? TextEngine.LineEnding {
                textEngine.convertLineEndings(to: lineEnding)
            }
        }
    }

    // MARK: - Actions

    private func newDocument() {
        // Clear current document and reset to blank state
        textEngine.loadText("")
        documentManager.currentDocument = nil
        documentManager.isModified = false
    }

    private func openFile() {
        documentManager.openDocument { result in
            switch result {
            case .success(let (content, docInfo)):
                textEngine.loadText(content)
                documentManager.currentDocument = docInfo
                documentManager.isModified = false

            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func saveFile() {
        guard documentManager.currentDocument != nil else {
            saveFileAs()
            return
        }

        Task {
            do {
                try await documentManager.save(content: textEngine.text)
                documentManager.isModified = false
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func saveFileAs() {
        documentManager.saveAs(content: textEngine.text) { result in
            switch result {
            case .success:
                documentManager.isModified = false

            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func runScript() {
        if scriptExecutor.isRunning {
            scriptExecutor.stopExecution()
        } else {
            guard let doc = documentManager.currentDocument, doc.isExecutable else {
                errorMessage = "Current file is not executable"
                showingError = true
                return
            }

            Task {
                do {
                    try await scriptExecutor.executeScript(
                        content: textEngine.text,
                        format: doc.format,
                        url: doc.url
                    )
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }
        }
    }

    private func exportAs(format: FileFormat) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "export.\(format.fileExtension)"
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    do {
                        let formatHandler = FileFormatHandler()
                        try await formatHandler.exportFile(
                            content: textEngine.text,
                            to: url,
                            format: format,
                            encoding: .utf8
                        )
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            showingError = true
                        }
                    }
                }
            }
        }
    }
}

extension String.Encoding {
    var description: String {
        switch self {
        case .utf8: return "UTF-8"
        case .utf16: return "UTF-16"
        case .utf16BigEndian: return "UTF-16 BE"
        case .utf16LittleEndian: return "UTF-16 LE"
        case .utf32: return "UTF-32"
        case .ascii: return "ASCII"
        case .isoLatin1: return "ISO Latin 1"
        case .macOSRoman: return "Mac Roman"
        case .windowsCP1252: return "Windows-1252"
        default: return "Unknown"
        }
    }
}
