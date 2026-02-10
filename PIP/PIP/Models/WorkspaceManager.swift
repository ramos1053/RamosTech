import Foundation
import SwiftUI
import Combine

/// Manages multiple workspaces
@MainActor
final class WorkspaceManager: ObservableObject {
    @Published var workspaces: [Workspace] = []
    @Published var activeWorkspaceID: UUID?

    private var workspaceCounter: Int = 1
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Create initial workspace
        createNewWorkspace()
    }

    var activeWorkspace: Workspace? {
        guard let id = activeWorkspaceID else { return nil }
        return workspaces.first { $0.id == id }
    }

    func createNewWorkspace() {
        let workspace = Workspace(name: "Workspace #\(workspaceCounter)")
        workspaceCounter += 1
        workspaces.append(workspace)

        // Forward workspace changes to WorkspaceManager
        workspace.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        // Set as active if it's the first one or if no active workspace
        if activeWorkspaceID == nil || workspaces.count == 1 {
            activeWorkspaceID = workspace.id
        }
    }

    func switchToWorkspace(_ id: UUID) {
        if workspaces.contains(where: { $0.id == id }) {
            activeWorkspaceID = id
        }
    }

    func closeWorkspace(_ workspace: Workspace) {
        guard workspaces.count > 1 else {
            // Don't close the last workspace
            return
        }

        if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
            workspaces.remove(at: index)

            // If we closed the active workspace, switch to another
            if activeWorkspaceID == workspace.id {
                if index < workspaces.count {
                    activeWorkspaceID = workspaces[index].id
                } else if !workspaces.isEmpty {
                    activeWorkspaceID = workspaces[workspaces.count - 1].id
                }
            }
        }
    }

    func renameWorkspace(_ workspace: Workspace, to newName: String) {
        workspace.name = newName
    }

    func moveWorkspace(from source: IndexSet, to destination: Int) {
        workspaces.move(fromOffsets: source, toOffset: destination)
    }

    // Check if any workspace has unsaved changes
    var hasUnsavedChanges: Bool {
        workspaces.contains { $0.hasUnsavedChanges }
    }

    // Get all unsaved documents across all workspaces
    var allUnsavedDocuments: [(workspace: Workspace, document: TabDocument)] {
        var result: [(Workspace, TabDocument)] = []
        for workspace in workspaces {
            for document in workspace.unsavedDocuments {
                result.append((workspace, document))
            }
        }
        return result
    }
}
