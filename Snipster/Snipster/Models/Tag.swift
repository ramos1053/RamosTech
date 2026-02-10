//
//  Tag.swift
//  Snipster
//
//  Created by Alan Ramos on 12/17/25.
//

import Foundation
import SwiftUI

struct Tag: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var color: Color
    var createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(),
         name: String,
         color: Color = .blue,
         createdAt: Date = Date(),
         modifiedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    mutating func updateName(_ newName: String) {
        name = newName
        modifiedAt = Date()
    }

    mutating func updateColor(_ newColor: Color) {
        color = newColor
        modifiedAt = Date()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.id == rhs.id
    }
}
