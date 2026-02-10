//
//  TagPillView.swift
//  Snipster
//
//  Created by Alan Ramos on 12/17/25.
//

import SwiftUI

struct TagPillView: View {
    let tag: Tag
    var showRemoveButton: Bool = false
    var onRemove: (() -> Void)?

    private var displayName: String {
        if tag.name.count > 6 {
            return String(tag.name.prefix(6)) + ".."
        }
        return tag.name
    }

    var body: some View {
        HStack(spacing: 4) {
            // Color circle indicator
            Circle()
                .fill(tag.color)
                .frame(width: 8, height: 8)

            Text("#\(displayName)")
                .font(.caption)
                .lineLimit(1)
                .fixedSize()

            if showRemoveButton, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tag.color.opacity(0.2))
        .foregroundColor(tag.color)
        .cornerRadius(12)
    }
}

#Preview {
    HStack {
        TagPillView(tag: Tag(name: "swift", color: .blue))
        TagPillView(tag: Tag(name: "work", color: .green), showRemoveButton: true) {
            print("Remove tapped")
        }
    }
    .padding()
}
