//
//  SnipsterApp.swift
//  Snipster
//
//  Created by Alan Ramos on 12/16/25.
//

import SwiftUI

@main
struct SnipsterApp: App {
    @StateObject private var viewModel = SnippetViewModel()

    var body: some Scene {
        MenuBarExtra("Snipster", systemImage: "doc.on.clipboard") {
            MenuBarPopoverView()
                .environmentObject(viewModel)
                .environmentObject(viewModel.tagStore)
                .onAppear {
                    // Set up the SpotlightWindowManager with the view model
                    SpotlightWindowManager.shared.setViewModel(viewModel)

                    // Initialize the hotkey manager (will register hotkey if enabled)
                    _ = HotkeyManager.shared
                }
        }
        .menuBarExtraStyle(.window)
    }
}
