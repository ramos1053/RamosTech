import SwiftUI

@main
struct GottaGoApp: App {
    @StateObject private var viewModel = BathroomViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
