package com.gottago.app.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gottago.app.model.Bathroom
import com.gottago.app.viewmodel.BathroomViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FavoritesScreen(viewModel: BathroomViewModel) {
    val favorites        by remember { derivedStateOf { viewModel.favorites } }
    var selectedBathroom by remember { mutableStateOf<Bathroom?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Favorites", fontWeight = FontWeight.Bold) },
                actions = {
                    if (favorites.isNotEmpty()) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.SwapVert, null, tint = Color.Gray, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(4.dp))
                            Text("Swipe to delete", fontSize = 11.sp, color = Color.Gray)
                            Spacer(Modifier.width(8.dp))
                        }
                    }
                }
            )
        }
    ) { padding ->
        if (favorites.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Default.HeartBroken, null, modifier = Modifier.size(64.dp), tint = Color.LightGray)
                    Spacer(Modifier.height(12.dp))
                    Text("No Favorites Yet", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Color.Gray)
                    Spacer(Modifier.height(4.dp))
                    Text("Tap the ♥ on any restroom to save it here\nfor quick access and one-tap navigation.",
                        fontSize = 13.sp, color = Color.LightGray, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                }
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(padding)
            ) {
                itemsIndexed(favorites, key = { _, b -> b.id }) { index, bathroom ->
                    // Swipe trailing = remove from favorites
                    // Swipe leading = delete (own entries only)
                    val dismissState = rememberSwipeToDismissBoxState(
                        confirmValueChange = { value ->
                            when (value) {
                                SwipeToDismissBoxValue.EndToStart -> {
                                    viewModel.toggleFavorite(bathroom) // un-favorite
                                    true
                                }
                                SwipeToDismissBoxValue.StartToEnd -> {
                                    if (viewModel.isLocalBathroom(bathroom)) {
                                        viewModel.deleteBathroom(bathroom)
                                        true
                                    } else false
                                }
                                else -> false
                            }
                        }
                    )
                    SwipeToDismissBox(
                        state = dismissState,
                        backgroundContent = {
                            val alignment = when (dismissState.dismissDirection) {
                                SwipeToDismissBoxValue.EndToStart -> Alignment.CenterEnd
                                else -> Alignment.CenterStart
                            }
                            val icon = when (dismissState.dismissDirection) {
                                SwipeToDismissBoxValue.StartToEnd -> Icons.Default.Delete
                                else -> Icons.Default.HeartBroken
                            }
                            Box(
                                modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
                                contentAlignment = alignment
                            ) {
                                Icon(icon, null, tint = Color.Red)
                            }
                        }
                    ) {
                        FavoriteRowCard(
                            bathroom = bathroom,
                            viewModel = viewModel,
                            onTap = { selectedBathroom = bathroom },
                            onRoute = { viewModel.setSelectedTab(1) } // Switch to map/nearby
                        )
                    }
                }
            }
        }
    }

    selectedBathroom?.let { bathroom ->
        BathroomDetailSheet(bathroom = bathroom, viewModel = viewModel) { selectedBathroom = null }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Favorite row card
// ──────────────────────────────────────────────────────────────────────────────

@Composable
fun FavoriteRowCard(
    bathroom: Bathroom,
    viewModel: BathroomViewModel,
    onTap: () -> Unit,
    onRoute: () -> Unit
) {
    val fc = feeColor(bathroom.fee)
    Card(onClick = onTap, modifier = Modifier.fillMaxWidth(), elevation = CardDefaults.cardElevation(2.dp)) {
        Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {

            // Heart tile
            Surface(shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp),
                color = Color.Red.copy(alpha = 0.12f), modifier = Modifier.size(52.dp)) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(Icons.Default.Favorite, null, tint = Color.Red, modifier = Modifier.size(24.dp))
                }
            }

            Spacer(Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(bathroom.name, fontWeight = FontWeight.Bold, maxLines = 1)
                if (bathroom.address.isNotEmpty())
                    Text(bathroom.address, fontSize = 12.sp, color = Color.Gray, maxLines = 1)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(bathroom.fee.displayName, fontSize = 11.sp, color = fc, fontWeight = FontWeight.SemiBold)
                    if (bathroom.averageRating > 0)
                        Text("★ ${"%.1f".format(bathroom.averageRating)}", fontSize = 11.sp, color = Color(0xFFF39C12))
                    viewModel.distanceText(bathroom)?.let { Text(it, fontSize = 11.sp, color = Color.LightGray) }
                }
            }

            // Navigate button
            IconButton(onClick = onRoute) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Default.Directions, "Navigate", tint = Color(0xFF2ECC71), modifier = Modifier.size(28.dp))
                    Text("Route", fontSize = 10.sp, color = Color(0xFF2ECC71), fontWeight = FontWeight.Bold)
                }
            }
        }
    }
}
