//
//  SnapshotViewModel.swift
//  Time Machine Manager
//
//  Created by Alan Ramos on 11/12/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SnapshotViewModel: ObservableObject {
    @Published var snapshots: [Snapshot] = []
    @Published var tmStatus: TMStatus = .disabled
    @Published var destinationInfo: DestinationInfo = DestinationInfo(name: "", kind: "", id: "", mountPoint: nil)
    @Published var diskSpace: DiskSpace = DiskSpace(total: "N/A", used: "N/A", available: "N/A", percentUsed: "N/A")
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingError = false
    @Published var successMessage: String?
    @Published var showingSuccess = false

    private let manager = TimeMachineManager.shared

    // MARK: - Computed Properties

    var snapshotCount: Int {
        snapshots.count
    }

    var estimatedSize: String {
        manager.estimateSnapshotSize(count: snapshotCount)
    }

    // MARK: - Load Data

    func loadData() {
        Task {
            isLoading = true
            defer { isLoading = false }

            let loadedSnapshots = await fetchSnapshots()
            let loadedStatus = await fetchStatus()
            let loadedDestInfo = await fetchDestinationInfo()
            let loadedDiskSpace = await fetchDiskSpace()

            snapshots = loadedSnapshots
            tmStatus = loadedStatus
            destinationInfo = loadedDestInfo
            diskSpace = loadedDiskSpace
        }
    }

    nonisolated private func fetchSnapshots() async -> [Snapshot] {
        return await TimeMachineManager.shared.listSnapshots()
    }

    nonisolated private func fetchStatus() async -> TMStatus {
        return await TimeMachineManager.shared.getStatus()
    }

    nonisolated private func fetchDestinationInfo() async -> DestinationInfo {
        return await TimeMachineManager.shared.getDestinationInfo()
    }

    nonisolated private func fetchDiskSpace() async -> DiskSpace {
        return await TimeMachineManager.shared.getDiskSpace()
    }

    // MARK: - Actions

    func toggleTimeMachine() {
        Task {
            isLoading = true
            defer { isLoading = false }

            let currentStatus = tmStatus
            let result = await performToggle(currentStatus: currentStatus)

            switch result {
            case .success:
                let newStatus = await fetchStatus()
                tmStatus = newStatus
                successMessage = tmStatus == .enabled ? "Time Machine enabled successfully" : "Time Machine disabled successfully"
                showingSuccess = true
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    nonisolated private func performToggle(currentStatus: TMStatus) async -> Result<Void, Error> {
        if currentStatus == .disabled {
            return await TimeMachineManager.shared.enableTimeMachine()
        } else {
            return await TimeMachineManager.shared.disableTimeMachine()
        }
    }

    func deleteSnapshot(_ snapshot: Snapshot) {
        Task {
            isLoading = true
            defer { isLoading = false }

            let result = await performDelete(snapshot: snapshot)

            switch result {
            case .success:
                let loadedSnapshots = await fetchSnapshots()
                snapshots = loadedSnapshots
                successMessage = "Snapshot deleted successfully"
                showingSuccess = true
            case .failure(let error):
                errorMessage = "Failed to delete snapshot: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    nonisolated private func performDelete(snapshot: Snapshot) async -> Result<Void, Error> {
        return await TimeMachineManager.shared.deleteSnapshot(snapshot)
    }
}
