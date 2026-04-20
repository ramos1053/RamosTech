package com.gottago.app.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.gottago.app.viewmodel.BathroomViewModel

@Composable
fun MainScreen(viewModel: BathroomViewModel) {
    val selectedTab   by viewModel.selectedTab.collectAsState()
    val favoritesCount = remember(viewModel.favorites) { viewModel.favorites.size }

    Scaffold(
        bottomBar = {
            NavigationBar(containerColor = MaterialTheme.colorScheme.surface) {
                NavigationBarItem(
                    selected      = selectedTab == 0,
                    onClick       = { viewModel.setSelectedTab(0) },
                    icon          = { Icon(Icons.Default.Home, "Home") },
                    label         = { Text("Home") },
                    alwaysShowLabel = true
                )
                NavigationBarItem(
                    selected      = selectedTab == 1,
                    onClick       = { viewModel.setSelectedTab(1) },
                    icon          = {
                        BadgedBox(badge = {}) {
                            Icon(Icons.Default.List, "Nearby")
                        }
                    },
                    label         = { Text("Nearby") },
                    alwaysShowLabel = true
                )
                NavigationBarItem(
                    selected      = selectedTab == 2,
                    onClick       = { viewModel.setSelectedTab(2) },
                    icon          = { Icon(Icons.Default.Map, "Map") },
                    label         = { Text("Map") },
                    alwaysShowLabel = true
                )
                NavigationBarItem(
                    selected      = selectedTab == 3,
                    onClick       = { viewModel.setSelectedTab(3) },
                    icon          = {
                        BadgedBox(
                            badge = {
                                if (favoritesCount > 0)
                                    Badge { Text(favoritesCount.toString()) }
                            }
                        ) {
                            Icon(
                                if (selectedTab == 3) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                                "Favorites"
                            )
                        }
                    },
                    label         = { Text("Favorites") },
                    alwaysShowLabel = true
                )
            }
        }
    ) { padding ->
        when (selectedTab) {
            0    -> HomeScreen(viewModel)
            1    -> NearbyScreen(viewModel)
            2    -> MapScreen(viewModel)
            else -> FavoritesScreen(viewModel)
        }
    }
}
