import SwiftUI

struct SnippetsView: View {
    @ObservedObject var snippetManager = SnippetManager.shared
    @State private var selectedSnippet: Snippet?
    @State private var editingSnippet: Snippet?
    @State private var isAddingNew = false
    @State private var showingImportExport = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Text Snippets")
                    .font(.headline)

                Spacer()

                Button("Edit") {
                    if let snippet = selectedSnippet {
                        editingSnippet = snippet
                        isAddingNew = false
                    }
                }
                .disabled(selectedSnippet == nil)
                .buttonStyle(.bordered)

                Button("Import/Export...") {
                    showingImportExport = true
                }
                .buttonStyle(.bordered)

                Button("Add Snippet") {
                    let newSnippet = Snippet(trigger: "", expansion: "", description: "")
                    editingSnippet = newSnippet
                    isAddingNew = true
                }
                .buttonStyle(.borderedProminent)

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()

            // Snippet List in bordered box
            VStack(spacing: 0) {
                HStack {
                    Text("Snippet Library")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                if snippetManager.snippets.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("No Snippets")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        Text("Create snippets to quickly insert text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedSnippet) {
                        ForEach(snippetManager.snippets) { snippet in
                            SnippetRow(snippet: snippet)
                                .tag(snippet)
                                .onTapGesture(count: 2) {
                                    editingSnippet = snippet
                                    isAddingNew = false
                                }
                                .contextMenu {
                                    Button("Edit") {
                                        editingSnippet = snippet
                                        isAddingNew = false
                                    }
                                    Button("Duplicate") {
                                        let duplicate = Snippet(
                                            trigger: snippet.trigger + "_copy",
                                            expansion: snippet.expansion,
                                            description: snippet.description
                                        )
                                        snippetManager.addSnippet(duplicate)
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        snippetManager.deleteSnippet(snippet)
                                    }
                                }
                        }
                        .onDelete(perform: snippetManager.deleteSnippets)
                    }
                }
            }
            .border(Color.secondary.opacity(0.3), width: 1)
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()

            // Footer with info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Double-click to edit • Snippets expand automatically when typing")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(snippetManager.snippetsFileURL.path, inFileViewerRootedAtPath: "")
                }
                .font(.caption)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditorView(
                snippet: snippet,
                isNew: isAddingNew,
                onSave: { edited in
                    if isAddingNew {
                        snippetManager.addSnippet(edited)
                    } else {
                        snippetManager.updateSnippet(edited)
                    }
                    editingSnippet = nil
                },
                onCancel: {
                    editingSnippet = nil
                }
            )
        }
        .sheet(isPresented: $showingImportExport) {
            ImportExportView()
        }
    }
}

struct SnippetRow: View {
    let snippet: Snippet

    var body: some View {
        HStack(spacing: 8) {
            Text(snippet.trigger)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.accentColor)
                .cornerRadius(4)
                .fixedSize()

            Text(snippet.expansion.prefix(80))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

struct SnippetEditorView: View {
    @State private var snippet: Snippet
    let isNew: Bool
    let onSave: (Snippet) -> Void
    let onCancel: () -> Void

    init(snippet: Snippet, isNew: Bool, onSave: @escaping (Snippet) -> Void, onCancel: @escaping () -> Void) {
        self._snippet = State(initialValue: snippet)
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isNew ? "New Snippet" : "Edit Snippet")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            // Form
            Form {
                Section {
                    HStack {
                        Text("Trigger:")
                            .frame(width: 100, alignment: .trailing)
                        TextField("e.g., !hello", text: $snippet.trigger)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("Description:")
                            .frame(width: 100, alignment: .trailing)
                        TextField("Optional description", text: $snippet.description)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expansion:")
                            .font(.headline)

                        TextEditor(text: $snippet.expansion)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 200)
                            .border(Color.secondary.opacity(0.3))
                    }
                }
            }
            .padding()

            Divider()

            // Buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save") {
                    onSave(snippet)
                }
                .keyboardShortcut(.return)
                .disabled(snippet.trigger.isEmpty || snippet.expansion.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
}

struct ImportExportView: View {
    @ObservedObject var snippetManager = SnippetManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Import/Export Snippets")
                .font(.headline)

            Divider()

            VStack(spacing: 12) {
                Button("Export Snippets...") {
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [.json]
                    panel.nameFieldStringValue = "snippets.json"
                    panel.begin { response in
                        if response == .OK, let url = panel.url {
                            do {
                                try snippetManager.exportSnippets(to: url)
                            } catch {
                                print("Export failed: \(error)")
                            }
                        }
                    }
                }
                .buttonStyle(.bordered)

                Button("Import Snippets (Merge)...") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.json]
                    panel.allowsMultipleSelection = false
                    panel.begin { response in
                        if response == .OK, let url = panel.urls.first {
                            do {
                                try snippetManager.importSnippets(from: url, replace: false)
                                dismiss()
                            } catch {
                                print("Import failed: \(error)")
                            }
                        }
                    }
                }
                .buttonStyle(.bordered)

                Button("Import Snippets (Replace All)...") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.json]
                    panel.allowsMultipleSelection = false
                    panel.begin { response in
                        if response == .OK, let url = panel.urls.first {
                            do {
                                try snippetManager.importSnippets(from: url, replace: true)
                                dismiss()
                            } catch {
                                print("Import failed: \(error)")
                            }
                        }
                    }
                }
                .buttonStyle(.bordered)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Snippets are stored at:")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Text(snippetManager.snippetsFileURL.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 500, height: 350)
    }
}
