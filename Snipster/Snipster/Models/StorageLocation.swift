//
//  StorageLocation.swift
//  Snipster
//
//  Created by RamosTech on 12/16/25.
//

import Foundation

enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case local = "Local Folder"
    /// A folder the user picked directly via NSOpenPanel. Works for iCloud
    /// Drive, OneDrive, Google Drive, Dropbox, or any external volume — it's
    /// just a folder, so no service-specific detection or entitlements are
    /// needed. The actual chosen path is tracked separately (see
    /// SnippetViewModel.customStoragePath), not on this case, matching how
    /// FileStorageManager already separates `storageLocation` from `customPath`.
    case custom = "Custom Folder"

    var id: String { rawValue }

    /// Only meaningful for `.local` — `.custom`'s path is whatever the user
    /// picked, not something this enum can compute on its own.
    var defaultPath: URL? {
        switch self {
        case .local:
            return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Snipster", isDirectory: true)
        case .custom:
            return nil
        }
    }

    var icon: String {
        switch self {
        case .local: return "folder.fill"
        case .custom: return "folder.badge.gearshape"
        }
    }
}
