//
//  SnippetListView.swift
//  Snipster
//
//  Created by RamosTech on 12/16/25.
//

import SwiftUI
import AppKit

struct SnippetListView: View {
    @EnvironmentObject var viewModel: SnippetViewModel
    @EnvironmentObject var tagStore: TagStore
    @Binding var selectedTag: Tag?
    @Binding var sortOption: SortOption
    @Binding var showFavoritesOnly: Bool
    @State private var selectedSnippet: Snippet?

    /// Checkbox-based multi-select, independent of `selectedSnippet` (the
    /// existing single-click-to-edit selection). A visible checkbox rather
    /// than Cmd/Shift-click, since the latter isn't discoverable without
    /// being told about it.
    @State private var checkedSnippetIDs: Set<UUID> = []
    @State private var pendingDeleteIDs: Set<UUID> = []
    @State private var showingBulkDeleteConfirm = false

    var filteredSnippets: [Snippet] {
        var snippets = viewModel.filteredSnippets

        // Filter by favorites
        if showFavoritesOnly {
            snippets = snippets.filter { $0.isFavorite }
        }

        // Filter by tag
        if let tag = selectedTag {
            snippets = snippets.filter { $0.tagIDs.contains(tag.id) }
        }

        // Apply sorting
        return viewModel.snippetStore.sortedSnippets(snippets, by: sortOption, tagStore: tagStore)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !checkedSnippetIDs.isEmpty {
                HStack {
                    Text("\(checkedSnippetIDs.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Cancel") {
                        checkedSnippetIDs.removeAll()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                    Button("Delete") {
                        requestDelete(checkedSnippetIDs)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(.controlBackgroundColor))
            }

            List(filteredSnippets, id: \.id) { snippet in
                HStack(spacing: 8) {
                    Button(action: { toggleChecked(snippet) }) {
                        Image(systemName: checkedSnippetIDs.contains(snippet.id) ? "checkmark.square.fill" : "square")
                            .foregroundColor(checkedSnippetIDs.contains(snippet.id) ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)

                    SnippetRowView(snippet: snippet)
                }
                .listRowBackground(
                    selectedSnippet?.id == snippet.id ? Color.accentColor.opacity(0.15) : Color.clear
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSnippet = snippet
                    WindowHelper.openSnippetDetailWindow(mode: .edit(snippet), viewModel: viewModel)
                }
                .onTapGesture(count: 2) {
                    // Double-click to copy
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippet.content, forType: .string)
                }
                .contextMenu {
                    if checkedSnippetIDs.count > 1 && checkedSnippetIDs.contains(snippet.id) {
                        Button("Delete \(checkedSnippetIDs.count) Snippets", role: .destructive) {
                            requestDelete(checkedSnippetIDs)
                        }
                    } else {
                        Button("Edit") {
                            WindowHelper.openSnippetDetailWindow(mode: .edit(snippet), viewModel: viewModel)
                        }

                        Button(snippet.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                            var updatedSnippet = snippet
                            updatedSnippet.toggleFavorite()
                            Task {
                                await viewModel.updateSnippet(updatedSnippet)
                            }
                        }

                        Divider()

                        Button("Duplicate") {
                            let duplicated = snippet.duplicate()
                            Task {
                                await viewModel.snippetStore.addSnippet(duplicated)
                            }
                        }

                        Button("Copy Content") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(snippet.content, forType: .string)
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            viewModel.deleteSnippet(snippet)
                            // Clear selection if deleting selected item
                            if selectedSnippet?.id == snippet.id {
                                selectedSnippet = nil
                            }
                            checkedSnippetIDs.remove(snippet.id)
                        }
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal)
            .onDeleteCommand {
                guard !checkedSnippetIDs.isEmpty else { return }
                requestDelete(checkedSnippetIDs)
            }
        }
        .alert(
            "Delete \(pendingDeleteIDs.count) Snippet\(pendingDeleteIDs.count == 1 ? "" : "s")?",
            isPresented: $showingBulkDeleteConfirm
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteSnippets(pendingDeleteIDs)
                checkedSnippetIDs.subtract(pendingDeleteIDs)
            }
        } message: {
            Text("This can't be undone.")
        }
    }

    private func toggleChecked(_ snippet: Snippet) {
        if checkedSnippetIDs.contains(snippet.id) {
            checkedSnippetIDs.remove(snippet.id)
        } else {
            checkedSnippetIDs.insert(snippet.id)
        }
    }

    private func requestDelete(_ ids: Set<UUID>) {
        pendingDeleteIDs = ids
        if ids.count > 1 {
            showingBulkDeleteConfirm = true
        } else {
            viewModel.deleteSnippets(ids)
            checkedSnippetIDs.subtract(ids)
        }
    }
}

#Preview {
    SnippetListView(selectedTag: .constant(nil), sortOption: .constant(.title), showFavoritesOnly: .constant(false))
        .environmentObject(SnippetViewModel())
        .environmentObject(TagStore(storageManager: FileStorageManager()))
}
