//
//  TagSelectorView.swift
//  Snipster
//
//  Created by Alan Ramos on 12/17/25.
//

import SwiftUI

struct TagSelectorView: View {
    @Binding var selectedTagIDs: [UUID]
    @EnvironmentObject var tagStore: TagStore
    @State private var showingAddTag = false

    private var selectedTags: [Tag] {
        tagStore.tags(byIDs: selectedTagIDs)
    }

    private var availableTags: [Tag] {
        tagStore.tags.filter { !selectedTagIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Selected tags section
            if !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Tags")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    FlowLayout {
                        ForEach(selectedTags) { tag in
                            TagPillView(tag: tag, showRemoveButton: true) {
                                removeTag(tag.id)
                            }
                        }
                    }
                }
            }

            // Available tags section
            if !availableTags.isEmpty {
                DisclosureGroup("Add Tags") {
                    FlowLayout {
                        ForEach(availableTags) { tag in
                            Button(action: { addTag(tag.id) }) {
                                TagPillView(tag: tag)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }
            }

            // Create new tag button
            Button(action: { showingAddTag = true }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Create New Tag")
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingAddTag) {
                TagEditView(tag: nil, onSave: { newTag in
                    Task {
                        await tagStore.addTag(newTag)
                        selectedTagIDs.append(newTag.id)
                    }
                })
            }
        }
    }

    private func addTag(_ tagID: UUID) {
        if !selectedTagIDs.contains(tagID) {
            selectedTagIDs.append(tagID)
        }
    }

    private func removeTag(_ tagID: UUID) {
        selectedTagIDs.removeAll { $0 == tagID }
    }
}

#Preview {
    TagSelectorView(selectedTagIDs: .constant([]))
        .environmentObject(TagStore(storageManager: FileStorageManager()))
        .padding()
}
