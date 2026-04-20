//
//  SystemMetrics.swift
//  Nimbus-Swift
//

import Foundation

struct SystemMetrics {
    var memoryUsageMB: Double // Server process memory in MB
    var cpuUsage: Double // CPU percentage 0.0 to 100.0
    var catalogSizeGB: Double // Cumulus catalog size in GB
    var timestamp: Date

    static let empty = SystemMetrics(
        memoryUsageMB: 0.0,
        cpuUsage: 0.0,
        catalogSizeGB: 0.0,
        timestamp: Date()
    )
}

struct ServerStatus {
    var isRunning: Bool
    var processID: Int?
    var uptime: String
    var metrics: SystemMetrics

    static let empty = ServerStatus(
        isRunning: false,
        processID: nil,
        uptime: "Unknown",
        metrics: .empty
    )
}
