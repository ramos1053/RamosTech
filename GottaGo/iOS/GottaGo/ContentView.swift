import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: BathroomViewModel

    var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            BathroomListView()
                .tabItem {
                    Label("Nearby", systemImage: "list.bullet")
                }
                .tag(1)

            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart.fill")
                }
                .tag(2)
                .badge(viewModel.favorites.count > 0 ? viewModel.favorites.count : 0)
        }
        .tint(.green)
    }
}
