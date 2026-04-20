//
//  Time_Machine_ManagerApp.swift
//  Time Machine Manager
//
//  Created by RamosTech on 11/12/25.
//

import SwiftUI

@main
struct Time_Machine_ManagerApp: App {
    var body: some Scene {
        WindowGroup("Time Machine Manager") {
            ContentView()
                .frame(width: 1140, height: 732)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1140, height: 732)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
