// HelpView.swift
// Tabby
//
// Comprehensive help documentation window with setup guides,
// usage instructions, and troubleshooting tips.
// Architecture mirrors the PIP project's HelpWindow style.

import SwiftUI

// MARK: - HelpView

struct HelpView: View {
    @State private var searchText = ""
    @State private var selectedCategory: HelpCategory = .gettingStarted

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                Section("Basics") {
                    ForEach(HelpCategory.basicsCategories) { category in
                        Label(category.title, systemImage: category.icon)
                            .tag(category)
                    }
                }

                Section("Browser Setup") {
                    ForEach(HelpCategory.setupCategories) { category in
                        Label(category.title, systemImage: category.icon)
                            .tag(category)
                    }
                }

                Section("Support") {
                    ForEach(HelpCategory.supportCategories) { category in
                        Label(category.title, systemImage: category.icon)
                            .tag(category)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            VStack(spacing: 0) {
                // Search bar — pinned above the scroll area
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search help...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top)

                Divider()
                    .padding(.horizontal)
                    .padding(.top, 8)

                ScrollView {
                    if searchText.isEmpty {
                        categoryContent(for: selectedCategory)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                    } else {
                        searchResults
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                    }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    // MARK: - Category Content

    @ViewBuilder
    private func categoryContent(for category: HelpCategory) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(category.title)
                .font(.largeTitle)
                .bold()

            Text(category.description)
                .font(.body)
                .foregroundColor(.secondary)

            Divider()

            ForEach(category.topics) { topic in
                VStack(alignment: .leading, spacing: 8) {
                    Text(topic.title)
                        .font(.title2)
                        .bold()

                    Text(topic.content)
                        .font(.body)

                    if !topic.details.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(topic.details, id: \.self) { detail in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\u{2022}")
                                        .foregroundColor(.secondary)
                                    Text(detail)
                                        .font(.body)
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)

                if topic.id != category.topics.last?.id {
                    Divider()
                }
            }
        }
    }

    // MARK: - Search Results

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Search Results")
                .font(.largeTitle)
                .bold()

            let results = searchHelpContent(query: searchText)

            if results.isEmpty {
                Text("No results found for '\(searchText)'")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 40)
            } else {
                ForEach(results) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(result.category)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor)
                                .cornerRadius(4)

                            Spacer()
                        }

                        Text(result.topic.title)
                            .font(.headline)

                        Text(result.topic.content)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(3)

                        Button("View") {
                            selectedCategory = result.categoryEnum
                            searchText = ""
                        }
                        .buttonStyle(.link)
                    }
                    .padding(.vertical, 8)

                    if result.id != results.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func searchHelpContent(query: String) -> [HelpSearchResult] {
        guard !query.isEmpty else { return [] }

        let lowercaseQuery = query.lowercased()
        var results: [HelpSearchResult] = []

        for category in HelpCategory.allCategories {
            for topic in category.topics {
                let searchableText = "\(topic.title) \(topic.content) \(topic.details.joined(separator: " "))"
                if searchableText.lowercased().contains(lowercaseQuery) {
                    results.append(HelpSearchResult(
                        category: category.title,
                        categoryEnum: category,
                        topic: topic
                    ))
                }
            }
        }

        return results
    }
}

// MARK: - Data Models

struct HelpCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let description: String
    let topics: [HelpTopic]

    static func == (lhs: HelpCategory, rhs: HelpCategory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct HelpTopic: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let details: [String]

    init(title: String, content: String, details: [String] = []) {
        self.title = title
        self.content = content
        self.details = details
    }
}

struct HelpSearchResult: Identifiable {
    let id = UUID()
    let category: String
    let categoryEnum: HelpCategory
    let topic: HelpTopic
}

// MARK: - Help Content

extension HelpCategory {
    static let gettingStarted = HelpCategory(
        title: "Getting Started",
        icon: "star.fill",
        description: "Learn the basics of using Tabby",
        topics: [
            HelpTopic(
                title: "Welcome to Tabby",
                content: "Tabby is a menu bar app that lets you see and manage all your open browser tabs in one place. It works with Google Chrome and Microsoft Edge."
            ),
            HelpTopic(
                title: "How It Works",
                content: "Tabby has two parts: a menu bar app (this app) that displays your tabs in a grid, and browser extensions that read your open tabs and send them to Tabby via Native Messaging.",
                details: [
                    "Tabby lives in your menu bar as an orange cat icon",
                    "Browser extensions communicate with Tabby in real time",
                    "Tabs are displayed in a Mission Control-style grid"
                ]
            ),
            HelpTopic(
                title: "Quick Start",
                content: "Get up and running in under a minute.",
                details: [
                    "Open Tabby Settings from the menu bar cat icon",
                    "Enable the extension for each browser you use",
                    "Follow the setup instructions shown for each browser",
                    "Press Cmd+Shift+T to open the Tabby window and see your tabs"
                ]
            )
        ]
    )

    static let keyboardShortcuts = HelpCategory(
        title: "Keyboard Shortcuts",
        icon: "keyboard",
        description: "Quick reference for keyboard shortcuts and usage",
        topics: [
            HelpTopic(
                title: "Global Hotkey",
                content: "Press your configured hotkey from anywhere to show or hide the Tabby window. The default is Cmd+Shift+T. You can change it in Settings.",
                details: [
                    "Default: Cmd+Shift+T — Toggle Tabby window",
                    "Customizable in Settings > Hotkey",
                    "Works globally from any application",
                    "May require Accessibility permissions in System Settings"
                ]
            ),
            HelpTopic(
                title: "Menu Bar",
                content: "Tabby lives in your menu bar as an orange cat icon. Click it to access all features.",
                details: [
                    "Show Tabby — Opens the tab grid window",
                    "Settings — Configure extensions and preferences",
                    "Help — This help guide",
                    "Quit Tabby — Closes the app completely"
                ]
            ),
            HelpTopic(
                title: "Tab Grid",
                content: "When the Tabby window is open, you can interact with your tabs in several ways.",
                details: [
                    "Click any tab tile to switch to that tab in its browser",
                    "Use the search bar to filter tabs by title or URL",
                    "Click the refresh button to fetch the latest tabs",
                    "Drag tiles to rearrange them within the grid",
                    "Right-click a tab tile to close it",
                    "Right-click a browser section header to close all tabs for that browser",
                    "Hover over a tile to see a preview of the page"
                ]
            ),
            HelpTopic(
                title: "Launch at Login",
                content: "You can set Tabby to start automatically when you log in. Go to Settings and enable \"Launch Tabby at Login\". Tabby will start silently in the menu bar."
            )
        ]
    )

    static let chromeSetup = HelpCategory(
        title: "Chrome Setup",
        icon: "globe",
        description: "Set up the Tabby extension in Google Chrome",
        topics: [
            HelpTopic(
                title: "Step 1: Enable in Tabby",
                content: "Open Tabby Settings (click the cat icon in the menu bar, then Settings). Turn on the Google Chrome toggle. This installs the Native Messaging host that lets Chrome talk to Tabby."
            ),
            HelpTopic(
                title: "Step 2: Open Chrome Extensions",
                content: "Type chrome://extensions into Chrome's address bar and press Enter."
            ),
            HelpTopic(
                title: "Step 3: Enable Developer Mode",
                content: "Look for the \"Developer mode\" toggle in the top-right corner of the page. Turn it on."
            ),
            HelpTopic(
                title: "Step 4: Load the Extension",
                content: "Click the \"Load unpacked\" button that appears in the top-left. A file picker will open. Navigate to the extension folder shown in Tabby Settings and click \"Select\"."
            ),
            HelpTopic(
                title: "Step 5: Verify",
                content: "You should see \"Tabby - Tab Enumerator\" in your extensions list. The Tabby icon may also appear in Chrome's toolbar. Press Cmd+Shift+T to open Tabby and see your Chrome tabs.",
                details: [
                    "The extension stays installed across Chrome restarts",
                    "You only need to do this setup once"
                ]
            )
        ]
    )

    static let edgeSetup = HelpCategory(
        title: "Edge Setup",
        icon: "globe",
        description: "Set up the Tabby extension in Microsoft Edge",
        topics: [
            HelpTopic(
                title: "Step 1: Enable in Tabby",
                content: "Open Tabby Settings and turn on the Microsoft Edge toggle."
            ),
            HelpTopic(
                title: "Step 2: Open Edge Extensions",
                content: "Type edge://extensions into Edge's address bar and press Enter."
            ),
            HelpTopic(
                title: "Step 3: Enable Developer Mode",
                content: "Look for the \"Developer mode\" toggle in the bottom-left of the page. Turn it on."
            ),
            HelpTopic(
                title: "Step 4: Load the Extension",
                content: "Click \"Load unpacked\" and select the extension folder shown in Tabby Settings."
            ),
            HelpTopic(
                title: "Step 5: Verify",
                content: "The Tabby extension should appear in your Edge extensions list. Press Cmd+Shift+T to see your tabs.",
                details: [
                    "The extension stays installed across Edge restarts",
                    "You only need to do this setup once"
                ]
            )
        ]
    )

    static let troubleshooting = HelpCategory(
        title: "Troubleshooting",
        icon: "wrench.and.screwdriver",
        description: "Solutions for common issues",
        topics: [
            HelpTopic(
                title: "Tabs Not Appearing",
                content: "If your browser tabs are not showing up in Tabby, try these steps.",
                details: [
                    "Make sure the extension is loaded in the browser (see setup guides)",
                    "Make sure the toggle is ON in Tabby Settings for that browser",
                    "Click the Refresh button in the Tabby window",
                    "Restart Tabby and reload the extension in the browser"
                ]
            ),
            HelpTopic(
                title: "Extension Disconnects",
                content: "If the extension loses connection to Tabby, the tabs will stop updating.",
                details: [
                    "Quit and reopen Tabby",
                    "In the browser, go to the extensions page and click the reload button on the Tabby extension"
                ]
            ),
            HelpTopic(
                title: "Hotkey Not Working",
                content: "If Cmd+Shift+T doesn't open Tabby, check the following.",
                details: [
                    "Make sure Tabby is running (check for the cat icon in the menu bar)",
                    "macOS may require Accessibility permissions — go to System Settings > Privacy & Security > Accessibility and allow Tabby",
                    "Another app might be using the same shortcut — check your other apps' keyboard shortcuts"
                ]
            ),
            HelpTopic(
                title: "Favicons Not Showing",
                content: "If tab tiles show a generic globe icon instead of the website's favicon, the browser extension needs to be reloaded.",
                details: [
                    "Quit and relaunch Tabby — this deploys the latest extension files",
                    "In Chrome, go to chrome://extensions and click the reload button (circular arrow) on the Tabby extension",
                    "In Edge, go to edge://extensions and click the reload button on the Tabby extension",
                    "Tabby fetches favicons using Chrome's built-in _favicon API, which requires the extension's service worker to be running the latest code",
                    "After updating Tabby, always reload the extension in each browser so it picks up the new service worker"
                ]
            ),
            HelpTopic(
                title: "Extension Out of Date After App Update",
                content: "When Tabby is updated, the browser extensions are automatically redeployed on launch. However, Chrome and Edge cache the extension's service worker and won't pick up changes until you manually reload.",
                details: [
                    "Launch the updated Tabby app (the new extension files are copied automatically)",
                    "Go to chrome://extensions (or edge://extensions)",
                    "Find \"Tabby - Tab Enumerator\" and click the reload button",
                    "You should see your tabs appear with favicons within a few seconds",
                    "Tip: You can verify the extension is connected by clicking the service worker link on the extensions page and checking the Console for \"[Tabby] Connected to native host\""
                ]
            ),
            HelpTopic(
                title: "Native Messaging Host Errors",
                content: "If you see errors about the native messaging host in the browser console, try these fixes.",
                details: [
                    "Quit Tabby, then toggle the browser OFF and ON again in Settings to reinstall the host manifest",
                    "Check that the TabbyHost binary exists inside the Tabby.app bundle",
                    "Make sure the Tabby app hasn't been moved after installing extensions"
                ]
            )
        ]
    )

    static let about = HelpCategory(
        title: "About Tabby",
        icon: "info.circle",
        description: "About this application",
        topics: [
            HelpTopic(
                title: "Tabby",
                content: "A lightweight menu bar app for managing browser tabs across Google Chrome and Microsoft Edge on macOS.",
                details: [
                    "Copyright \u{00A9} 2025-2026 A. Ramos, RamosTech",
                    "All rights reserved."
                ]
            )
        ]
    )

    // Category collections
    static let basicsCategories = [gettingStarted, keyboardShortcuts]
    static let setupCategories = [chromeSetup, edgeSetup]
    static let supportCategories = [troubleshooting, about]
    static let allCategories = basicsCategories + setupCategories + supportCategories
}
