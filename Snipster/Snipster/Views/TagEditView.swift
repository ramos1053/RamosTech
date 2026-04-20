//
//  TagEditView.swift
//  Snipster
//
//  Created by Alan Ramos on 12/17/25.
//

import SwiftUI

struct TagEditView: View {
    let tag: Tag?  // nil for creating new tag
    var onSave: ((Tag) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedColor: Color = .blue

    var isEditing: Bool {
        tag != nil
    }

    var title: String {
        isEditing ? "Edit Tag" : "New Tag"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    saveTag()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Tag Name") {
                    TextField("Enter tag name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .padding(.vertical, 4)
                }

                Section("Tag Color") {
                    ColorPicker("Choose color", selection: $selectedColor)
                        .padding(.vertical, 4)
                }

                Section("Preview") {
                    HStack {
                        Text("Preview:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !name.isEmpty {
                            TagPillView(tag: Tag(name: name, color: selectedColor))
                        } else {
                            Text("Enter a name to see preview")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
        .frame(width: 400, height: 350)
        .onAppear {
            if let tag = tag {
                name = tag.name
                selectedColor = tag.color
            }
        }
    }

    private func saveTag() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let savedTag: Tag
        if let existingTag = tag {
            var updatedTag = existingTag
            updatedTag.updateName(trimmedName)
            updatedTag.updateColor(selectedColor)
            savedTag = updatedTag
        } else {
            savedTag = Tag(name: trimmedName, color: selectedColor)
        }

        onSave?(savedTag)
        dismiss()
    }
}

#Preview {
    TagEditView(tag: nil)
}
