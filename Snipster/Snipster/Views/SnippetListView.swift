//
//  SnippetListView.swift
//  Snipster
//
//  Created by Alan Ramos on 12/16/25.
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
        List(filteredSnippets, id: \.id) { snippet in
            SnippetRowView(snippet: snippet)
                .listRowBackground(
                    selectedSnippet?.id == snippet.id ? Color.accentColor.opacity(0.15) : Color.clear
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSnippet = snippet
                    viewModel.selectSnippet(snippet)
                    WindowHelper.openSnippetDetailWindow(mode: .edit(snippet), viewModel: viewModel)
                }
                .onTapGesture(count: 2) {
                    // Double-click to copy
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippet.content, forType: .string)
                }
                .contextMenu {
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
    }
}

#Preview {
    SnippetListView(selectedTag: .constant(nil), sortOption: .constant(.title), showFavoritesOnly: .constant(false))
        .environmentObject(SnippetViewModel())
        .environmentObject(TagStore(storageManager: FileStorageManager()))
}
