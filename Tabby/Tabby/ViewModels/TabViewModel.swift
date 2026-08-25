// TabViewModel.swift
// Tabby
//
// Main view model that aggregates tab data from all browsers and provides
// the data source for the Mission Control grid UI. Also handles tab activation.

import SwiftUI
import Combine

// MARK: - TabViewModel

/// Central view model that manages all browser tabs and coordinates with
/// the Native Messaging host.
@MainActor
final class TabViewModel: ObservableObject {

    // MARK: - Published Properties

    /// All tabs from all browsers, sorted by browser then by window/tab order
    @Published var allTabs: [BrowserTab] = []

    /// Tabs grouped by browser for sectioned display
    @Published var tabsByBrowser: [Browser: [BrowserTab]] = [:]

    /// Current search/filter text
    @Published var searchText: String = ""

    /// Whether any extensions are currently connected
    @Published var hasConnectedExtensions: Bool = false

    /// Filtered tabs based on search text
    var filteredTabs: [BrowserTab] {
        if searchText.isEmpty {
            return allTabs
        }
        let query = searchText.lowercased()
        return allTabs.filter { tab in
            tab.title.lowercased().contains(query) ||
            tab.url.lowercased().contains(query)
        }
    }

    /// Filtered tabs grouped by browser
    var filteredTabsByBrowser: [Browser: [BrowserTab]] {
        Dictionary(grouping: filteredTabs, by: \.browser)
    }

    // MARK: - Services

    let nativeMessagingHost = NativeMessagingHost()

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        setupBindings()
    }

    // MARK: - Public API

    /// Start monitoring all installed extensions.
    func startMonitoring() {
        for browser in Browser.allCases {
            if ExtensionInstaller.isInstalled(for: browser) {
                nativeMessagingHost.startListening(for: browser)
            }
        }
    }

    /// Stop all monitoring.
    func stopMonitoring() {
        for browser in Browser.allCases {
            nativeMessagingHost.stopListening(for: browser)
        }
    }

    /// Activate a specific tab — sends the command to the right browser.
    func activateTab(_ tab: BrowserTab) {
        nativeMessagingHost.activateTab(tab)
    }

    /// Close a specific tab in its browser.
    func closeTab(_ tab: BrowserTab) {
        nativeMessagingHost.closeTab(tab)
    }

    /// Close all tabs for a specific browser.
    func closeAllTabs(for browser: Browser) {
        nativeMessagingHost.closeAllTabs(for: browser)
    }

    /// Move a tab to a new position (for drag-and-drop reordering).
    func moveTab(_ source: BrowserTab, to destination: BrowserTab) {
        guard source.browser == destination.browser else { return }
        guard let sourceIndex = allTabs.firstIndex(where: { $0.id == source.id }),
              let destIndex = allTabs.firstIndex(where: { $0.id == destination.id }) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            allTabs.move(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: destIndex > sourceIndex ? destIndex + 1 : destIndex
            )
            tabsByBrowser = Dictionary(grouping: allTabs, by: \.browser)
        }
    }

    /// Request a refresh of tabs from all browsers.
    /// Also starts listening for any newly installed browser extensions.
    func refreshAllTabs() {
        for browser in Browser.allCases {
            if ExtensionInstaller.isInstalled(for: browser) {
                // Start listening if not already (handles newly installed extensions)
                nativeMessagingHost.startListening(for: browser)
                nativeMessagingHost.requestTabs(from: browser)
            }
        }
    }

    // MARK: - Private

    private func setupBindings() {
        // Observe native messaging tab updates
        nativeMessagingHost.$tabsByBrowser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nativeTabs in
                self?.updateAllTabs(nativeTabs: nativeTabs)
            }
            .store(in: &cancellables)
    }

    private func updateAllTabs(nativeTabs: [Browser: [BrowserTab]]) {
        var combined: [BrowserTab] = []

        // Add Chrome tabs
        combined.append(contentsOf: nativeTabs[.chrome] ?? [])

        // Add Edge tabs
        combined.append(contentsOf: nativeTabs[.edge] ?? [])

        allTabs = combined
        tabsByBrowser = Dictionary(grouping: combined, by: \.browser)
        hasConnectedExtensions = !combined.isEmpty
    }
}
