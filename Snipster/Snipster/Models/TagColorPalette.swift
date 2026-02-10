//
//  TagColorPalette.swift
//  Snipster
//
//  Created by Alan Ramos on 12/17/25.
//

import SwiftUI

struct TagColorPalette {
    static let defaultColors: [Color] = [
        .blue,
        .green,
        .orange,
        .purple,
        .pink,
        .red,
        .yellow,
        .teal,
        .indigo,
        .cyan
    ]

    /// Returns the next color from the palette based on the number of existing tags
    static func nextColor(existingTags: [Tag]) -> Color {
        let index = existingTags.count % defaultColors.count
        return defaultColors[index]
    }

    /// Returns a random color from the palette
    static func randomColor() -> Color {
        defaultColors.randomElement() ?? .blue
    }
}
