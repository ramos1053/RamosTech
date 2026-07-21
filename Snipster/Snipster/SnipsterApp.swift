//
//  SnipsterApp.swift
//  Snipster
//
//  Created by RamosTech on 12/16/25.
//

import SwiftUI

@main
struct SnipsterApp: App {
    @StateObject private var viewModel = SnippetViewModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Snipster", systemImage: "doc.on.clipboard") {
            MenuBarPopoverView()
                .environmentObject(viewModel)
                .environmentObject(viewModel.tagStore)
                .onAppear {
                    // Set up the SpotlightWindowManager with the view model
                    SpotlightWindowManager.shared.setViewModel(viewModel)
                }
        }
        .menuBarExtraStyle(.window)
    }
}

// MenuBarExtra's content view (and its onAppear) isn't guaranteed to render
// until the user clicks the menu bar icon at least once, so anything that
// needs to be live immediately at launch (hotkey registration, the Finder
// "Copy Path" service) is started here instead, which always runs.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = HotkeyManager.shared
        _ = CopyPathService.shared
    }
}
