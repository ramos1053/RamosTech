//
//  NimbusSwiftApp.swift
//  Nimbus-Swift
//
//  Modern Swift rewrite of Nimbus - Cumulus Server Management
//
// RamosTech - RamosTech - 2025

import SwiftUI

@main
struct NimbusSwiftApp: App {
    @StateObject private var preferencesManager = PreferencesManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(preferencesManager)
                .frame(width: 650, height: 550)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 650, height: 550)
        .commands {
            CommandGroup(replacing: .help) {
                Button("Nimbus Online Help") {
                    if let url = URL(string: "https://www.sporksoftware.com/nimbus/nimbus_docs.html") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(preferencesManager)
        }
    }
}
