//
//  SortOption.swift
//  Snipster
//
//  Created by Alan Ramos on 12/17/25.
//

import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case title = "Title"
    case tag = "Tag"
    case color = "Color"
    case dateCreated = "Date Created"
    case dateModified = "Date Modified"

    var id: String { rawValue }
}
