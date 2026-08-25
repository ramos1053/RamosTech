// MissionControlView.swift
// Tabby
//
// The main Mission Control-style grid view that displays all browser tabs.
// Tabs are organized by browser in sections, displayed in a responsive grid.
// Tiles can be dragged and reordered within the grid.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - MissionControlView

struct MissionControlView: View {
    @ObservedObject var viewModel: TabViewModel

    /// Adaptive grid columns
    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 12)
    ]

    /// Currently dragged tab for reordering
    @State private var draggingTab: BrowserTab?

    /// Tracks which browser sections are collapsed
    @State private var collapsedBrowsers: Set<Browser> = []

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if viewModel.allTabs.isEmpty {
                emptyStateView
            } else {
                tabGridView
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search tabs...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: { viewModel.refreshAllTabs() }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh all tabs")

            Text("\(viewModel.filteredTabs.count) tabs")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Tab Grid

    private var tabGridView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(Browser.allCases) { browser in
                    let tabs = viewModel.filteredTabsByBrowser[browser] ?? []
                    if !tabs.isEmpty {
                        browserSection(browser: browser, tabs: tabs)
                    }
                }
            }
            .padding(16)
        }
    }

    private func browserSection(browser: Browser, tabs: [BrowserTab]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { !collapsedBrowsers.contains(browser) },
                    set: { isExpanded in
                        if isExpanded {
                            collapsedBrowsers.remove(browser)
                        } else {
                            collapsedBrowsers.insert(browser)
                        }
                    }
                )
            ) {
                // Tab tiles grid with drag-and-drop
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(tabs) { tab in
                        TabTileView(tab: tab) {
                            viewModel.activateTab(tab)
                        }
                        .opacity(draggingTab?.id == tab.id ? 0.5 : 1.0)
                        .onDrag {
                            draggingTab = tab
                            return NSItemProvider(object: tab.id as NSString)
                        }
                        .onDrop(of: [.text], delegate: TabDropDelegate(
                            tab: tab,
                            viewModel: viewModel,
                            draggingTab: $draggingTab
                        ))
                        .transition(.scale.combined(with: .opacity))
                        .contextMenu {
                            Button("Close Tab") {
                                viewModel.closeTab(tab)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: browser.sfSymbolName)
                        .font(.system(size: 16, weight: .semibold))

                    Text(browser.displayName)
                        .font(.system(size: 15, weight: .semibold))

                    Text("(\(tabs.count))")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 4)
                .contextMenu {
                    Button("Close All Tabs") {
                        viewModel.closeAllTabs(for: browser)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Tabs Found")
                .font(.title2)
                .foregroundColor(.primary)

            Text("Install browser extensions in Settings\nand open some browser tabs to get started.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            SettingsLink {
                Text("Open Settings")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tab Drop Delegate

struct TabDropDelegate: DropDelegate {
    let tab: BrowserTab
    let viewModel: TabViewModel
    @Binding var draggingTab: BrowserTab?

    func performDrop(info: DropInfo) -> Bool {
        draggingTab = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let source = draggingTab,
              source.id != tab.id,
              source.browser == tab.browser else { return }

        viewModel.moveTab(source, to: tab)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
