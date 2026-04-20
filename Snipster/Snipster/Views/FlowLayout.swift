//
//  FlowLayout.swift
//  Snipster
//
//  Created by Alan Ramos on 12/17/25.
//

import SwiftUI

/// A simple flow layout that wraps content to the next line when needed
struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        // Use a simple wrapping approach with LazyVGrid
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 50, maximum: 200), spacing: spacing)],
            alignment: .leading,
            spacing: spacing
        ) {
            content()
        }
    }
}

#Preview {
    FlowLayout {
        ForEach(0..<10) { index in
            Text("Tag \(index)")
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(12)
        }
    }
    .padding()
}
