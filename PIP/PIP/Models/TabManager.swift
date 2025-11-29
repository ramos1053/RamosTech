import Foundation
import SwiftUI

/// Manages multiple open document tabs
@MainActor
final class TabManager: ObservableObject {
    @Published var tabs: [TabDocument] = []
    @Published var activeTabID: UUID?
    @Published var showCloseConfirmation: Bool = false
    @Published var tabToClose: TabDocument?

    var activeTab: TabDocument? {
        guard let id = activeTabID else { return nil }
        return tabs.first { $0.id == id }
    }

    init() {
        // No tabs by default - user must open a file or create a new tab
    }

    /// Creates a new blank tab
    func createNewTab() {
        let newTab = TabDocument()
        tabs.append(newTab)
        activeTabID = newTab.id
        objectWillChange.send()
    }

    /// Opens a file in a new tab, or switches to existing tab if already open
    func openFile(content: String, documentInfo: DocumentManager.DocumentInfo) {
        // Check if file is already open
        if let existingTab = tabs.first(where: { $0.documentInfo?.url == documentInfo.url }) {
            // Switch to existing tab
            activeTabID = existingTab.id
            objectWillChange.send()
            return
        }

        // Create new tab for this file
        let newTab = TabDocument()
        newTab.loadContent(content, documentInfo: documentInfo)
        tabs.append(newTab)
        activeTabID = newTab.id
        objectWillChange.send()
    }

    /// Switches to a specific tab
    func switchToTab(_ tabID: UUID) {
        if tabs.contains(where: { $0.id == tabID }) {
            activeTabID = tabID
            objectWillChange.send()
        }
    }

    /// Moves a tab from one position to another
    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
    }

    /// Moves a tab by ID to a new index
    func moveTab(tabID: UUID, to newIndex: Int) {
        guard let currentIndex = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        let tab = tabs.remove(at: currentIndex)
        let insertIndex = min(max(0, newIndex), tabs.count)
        tabs.insert(tab, at: insertIndex)
    }

    /// Attempts to close a tab, prompting for save if needed
    func closeTab(_ tab: TabDocument) {
        if tab.isModified {
            // Show confirmation dialog
            tabToClose = tab
            showCloseConfirmation = true
        } else {
            // Close immediately
            performCloseTab(tab)
        }
    }

    /// Force closes a tab without prompting
    func performCloseTab(_ tab: TabDocument) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }

        // If closing active tab, switch to another tab
        if activeTabID == tab.id {
            if tabs.count > 1 {
                // Switch to previous tab, or next if first
                if index > 0 {
                    activeTabID = tabs[index - 1].id
                } else if index < tabs.count - 1 {
                    activeTabID = tabs[index + 1].id
                }
            } else {
                // This was the last tab, set activeTabID to nil (no tabs)
                activeTabID = nil
            }
        }

        // Remove the tab
        tabs.remove(at: index)
    }

    /// Saves the tab to close after confirmation
    func saveAndCloseTab() {
        guard let tab = tabToClose else { return }
        // The actual save will be handled by ContentView
        // This just marks that we want to save and close
        NotificationCenter.default.post(name: .saveAndCloseTab, object: tab.id)
        showCloseConfirmation = false
        tabToClose = nil
    }

    /// Closes the tab without saving after confirmation
    func discardAndCloseTab() {
        guard let tab = tabToClose else { return }
        performCloseTab(tab)
        showCloseConfirmation = false
        tabToClose = nil
    }

    /// Cancels the close operation
    func cancelClose() {
        showCloseConfirmation = false
        tabToClose = nil
    }

    /// Checks if a file URL is already open
    func isFileOpen(_ url: URL) -> Bool {
        tabs.contains { $0.documentInfo?.url == url }
    }

    /// Gets tab by ID
    func getTab(byID id: UUID) -> TabDocument? {
        tabs.first { $0.id == id }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let saveAndCloseTab = Notification.Name("saveAndCloseTab")
}
