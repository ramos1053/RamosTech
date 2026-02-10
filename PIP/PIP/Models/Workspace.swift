import Foundation
import Combine

/// Represents a workspace containing multiple document tabs
@MainActor
final class Workspace: ObservableObject, Identifiable {
    let id = UUID()

    @Published var name: String
    let tabManager: TabManager

    private var cancellables = Set<AnyCancellable>()

    init(name: String) {
        self.name = name
        self.tabManager = TabManager()

        // Forward TabManager changes to this Workspace's objectWillChange
        tabManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    var hasUnsavedChanges: Bool {
        tabManager.tabs.contains { $0.isModified }
    }

    var unsavedDocuments: [TabDocument] {
        tabManager.tabs.filter { $0.isModified }
    }
}
