//
//  SnippetDetailView.swift
//  Snipster
//
//  Created by Alan Ramos on 12/16/25.
//

import SwiftUI

struct SnippetDetailView: View {
    enum Mode {
        case add
        case edit(Snippet)

        var title: String {
            switch self {
            case .add: return "New Snippet"
            case .edit: return "Edit Snippet"
            }
        }
    }

    let mode: Mode

    @EnvironmentObject var viewModel: SnippetViewModel
    @EnvironmentObject var tagStore: TagStore

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var selectedTagIDs: [UUID] = []
    @State private var triggerPrefix: String = "!"
    @State private var triggerSequence: String = ""
    @State private var isFavorite: Bool = false
    @State private var triggerConflictSnippet: Snippet?

    @FocusState private var titleFieldFocused: Bool

    private var currentSnippetID: UUID? {
        if case .edit(let snippet) = mode {
            return snippet.id
        }
        return nil
    }

    private var hasTriggerConflict: Bool {
        triggerConflictSnippet != nil
    }

    private func closeWindow() {
        if let window = NSApplication.shared.keyWindow {
            window.close()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(mode.title)
                    .font(.headline)

                Button(action: { isFavorite.toggle() }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundColor(isFavorite ? .yellow : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help(isFavorite ? "Remove from favorites" : "Add to favorites")

                Spacer()

                Button("Cancel") {
                    closeWindow()
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    saveSnippet()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(title.isEmpty || content.isEmpty || hasTriggerConflict)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Title") {
                    TextField("Snippet title", text: $title)
                        .focused($titleFieldFocused)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 4)
                }

                Section("Trigger") {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Prefix")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("", text: $triggerPrefix)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                                .onChange(of: triggerPrefix) { oldValue, newValue in
                                    checkTriggerConflict()
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Keyword")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("", text: $triggerSequence)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: triggerSequence) { oldValue, newValue in
                                    checkTriggerConflict()
                                }
                        }
                    }
                    .padding(.vertical, 4)

                    if let conflictSnippet = triggerConflictSnippet {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Trigger '\(triggerPrefix)\(triggerSequence)' is already used by '\(conflictSnippet.title)'")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    } else if !triggerSequence.isEmpty {
                        Text("Type \(triggerPrefix)\(triggerSequence) anywhere to expand this snippet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                        .font(.body)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }

                Section("Tags") {
                    TagSelectorView(selectedTagIDs: $selectedTagIDs)
                        .padding(.vertical, 4)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            if case .edit(let snippet) = mode {
                title = snippet.title
                content = snippet.content
                selectedTagIDs = snippet.tagIDs
                triggerPrefix = snippet.triggerPrefix
                triggerSequence = snippet.triggerSequence
                isFavorite = snippet.isFavorite
            }
            titleFieldFocused = true
        }
    }

    private func checkTriggerConflict() {
        triggerConflictSnippet = viewModel.findConflictingTrigger(
            prefix: triggerPrefix,
            sequence: triggerSequence,
            excludingSnippetID: currentSnippetID
        )
    }

    private func saveSnippet() {
        // Double-check for conflicts before saving
        guard !hasTriggerConflict else { return }

        switch mode {
        case .add:
            viewModel.addSnippet(title: title, content: content, tagIDs: selectedTagIDs, triggerPrefix: triggerPrefix, triggerSequence: triggerSequence, isFavorite: isFavorite)
        case .edit(var snippet):
            snippet.updateTitle(title)
            snippet.updateContent(content)
            snippet.updateTagIDs(selectedTagIDs)
            snippet.updateTrigger(prefix: triggerPrefix, sequence: triggerSequence)
            snippet.isFavorite = isFavorite
            viewModel.updateSnippet(snippet)
        }

        closeWindow()
    }
}

#Preview {
    let viewModel = SnippetViewModel()
    return SnippetDetailView(mode: .add)
        .environmentObject(viewModel)
        .environmentObject(viewModel.tagStore)
}
