//
//  AppPreferences.swift
//  Nimbus-Swift
//

import Foundation

struct AppPreferences: Codable {
    var serverPath: String
    var catalogPath: String
    var backupPath: String

    static let `default` = AppPreferences(
        serverPath: "/usr/local/Cumulus5/",
        catalogPath: "/usr/local/Cumulus5/",
        backupPath: "None Specified"
    )
}
