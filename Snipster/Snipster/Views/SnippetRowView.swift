//
//  SnippetRowView.swift
//  Snipster
//
//  Created by Alan Ramos on 12/16/25.
//

import SwiftUI

struct SnippetRowView: View {
    let snippet: Snippet
    @EnvironmentObject var tagStore: TagStore
    @EnvironmentObject var viewModel: SnippetViewModel
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: toggleFavorite) {
                    Image(systemName: snippet.isFavorite ? "star.fill" : "star")
                        .foregroundColor(snippet.isFavorite ? .yellow : .secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help(snippet.isFavorite ? "Remove from favorites" : "Add to favorites")

                Text(snippet.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if snippet.usageCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption2)
                        Text("\(snippet.usageCount)")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                }

                if !snippet.trigger.isEmpty {
                    Text(snippet.trigger)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor)
                        .cornerRadius(4)
                }
            }

            if settings.previewLines > 0 {
                Text(snippet.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(settings.previewLines)
            }

            if !snippet.tagIDs.isEmpty {
                HStack {
                    ForEach(tagStore.tags(byIDs: snippet.tagIDs)) { tag in
                        TagPillView(tag: tag)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func toggleFavorite() {
        var updatedSnippet = snippet
        updatedSnippet.toggleFavorite()
        Task {
            await viewModel.updateSnippet(updatedSnippet)
        }
    }
}

#Preview {
    SnippetRowView(snippet: Snippet(title: "Test Snippet", content: "This is a test snippet with some content", tags: ["swift", "test"], triggerPrefix: "!", triggerSequence: "te"))
        .environmentObject(SnippetViewModel())
        .padding()
}
