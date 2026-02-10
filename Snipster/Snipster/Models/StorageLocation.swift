//
//  StorageLocation.swift
//  Snipster
//
//  Created by Alan Ramos on 12/16/25.
//

import Foundation

enum StorageLocation: String, Codable, CaseIterable, Identifiable {
    case local = "Local Folder"
    case iCloud = "iCloud Drive"
    case oneDrive = "OneDrive"

    var id: String { rawValue }

    nonisolated var defaultPath: URL? {
        switch self {
        case .local:
            return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Snipster", isDirectory: true)
        case .iCloud:
            return FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents/Snipster", isDirectory: true)
        case .oneDrive:
            // OneDrive typically at ~/Library/CloudStorage/OneDrive-Personal/
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let oneDrivePath = homeDir.appendingPathComponent("Library/CloudStorage", isDirectory: true)

            // Try to find OneDrive folder (could be OneDrive-Personal, OneDrive-Business, etc.)
            if let contents = try? FileManager.default.contentsOfDirectory(at: oneDrivePath, includingPropertiesForKeys: nil),
               let oneDriveFolder = contents.first(where: { $0.lastPathComponent.starts(with: "OneDrive") }) {
                return oneDriveFolder.appendingPathComponent("Apps/Snipster", isDirectory: true)
            }
            return nil
        }
    }

    var icon: String {
        switch self {
        case .local: return "folder.fill"
        case .iCloud: return "icloud.fill"
        case .oneDrive: return "cloud.fill"
        }
    }

    nonisolated var needsPermission: Bool {
        switch self {
        case .local: return false
        case .iCloud: return true
        case .oneDrive: return true
        }
    }
}
