package com.gottago.app.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
fun NearbyScreen(viewModel: BathroomViewModel) {
    val searchText by viewModel.searchText.collectAsState()
    val sorted     = remember(viewModel.sortedByDistance, searchText) { viewModel.sortedByDistance }
    var selectedBathroom by remember { mutableStateOf<Bathroom?>(null) }
    var showAdd          by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Nearby Bathrooms", fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    // Filter menu
                    val filterCount = listOf(
                        viewModel.filterFreeOnly.collectAsState().value,
                        viewModel.filterAccessibleOnly.collectAsState().value,
                        viewModel.filterGenderNeutral.collectAsState().value
                    ).count { it }
                    val freeOnly       by viewModel.filterFreeOnly.collectAsState()
                    val accessibleOnly by viewModel.filterAccessibleOnly.collectAsState()
                    val genderNeutral  by viewModel.filterGenderNeutral.collectAsState()
                    var menuExpanded   by remember { mutableStateOf(false) }

                    Box {
                        IconButton(onClick = { menuExpanded = true }) {
                            Icon(
                                if (filterCount > 0) Icons.Default.FilterAlt else Icons.Default.FilterAltOff,
                                "Filter",
                                tint = if (filterCount > 0) Color(0xFF2ECC71) else LocalContentColor.current
                            )
                        }
                        DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                            DropdownMenuItem(
                                text = { Text("Free Only") },
                                onClick = { viewModel.setFilterFreeOnly(!freeOnly) },
                                trailingIcon = { if (freeOnly) Icon(Icons.Default.Check, null, tint = Color(0xFF2ECC71)) }
                            )
                            DropdownMenuItem(
                                text = { Text("Accessible Only") },
                                onClick = { viewModel.setFilterAccessibleOnly(!accessibleOnly) },
                                trailingIcon = { if (accessibleOnly) Icon(Icons.Default.Check, null, tint = Color(0xFF2ECC71)) }
                            )
                            DropdownMenuItem(
                                text = { Text("Gender Neutral Only") },
                                onClick = { viewModel.setFilterGenderNeutral(!genderNeutral) },
                                trailingIcon = { if (genderNeutral) Icon(Icons.Default.Check, null, tint = Color(0xFF2ECC71)) }
                            )
                        }
                    }
                },
                actions = {
                    IconButton(onClick = { showAdd = true }) {
                        Icon(Icons.Default.AddCircle, "Add", tint = Color(0xFF2ECC71))
                    }
                }
            )
        }
    ) { padding ->
        Column(modifier = Modifier.padding(padding)) {
            // Search bar
            SearchBar(
                query = searchText,
                onQueryChange = { viewModel.setSearchText(it) },
                onSearch = {},
                active = false,
                onActiveChange = {},
                placeholder = { Text("Search by name or address…") },
                leadingIcon  = { Icon(Icons.Default.Search, null) },
                trailingIcon = {
                    if (searchText.isNotEmpty()) {
                        IconButton(onClick = { viewModel.setSearchText("") }) {
                            Icon(Icons.Default.Clear, "Clear")
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp)
            ) {}

            if (sorted.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Default.SearchOff, null, modifier = Modifier.size(56.dp), tint = Color.LightGray)
                        Spacer(Modifier.height(8.dp))
                        Text("No bathrooms found", fontSize = 16.sp, color = Color.Gray)
                        Text("Try adjusting your filters or tap + to add one", fontSize = 12.sp, color = Color.LightGray)
                    }
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(sorted, key = { it.id }) { bathroom ->
                        val dismissState = rememberSwipeToDismissBoxState(
                            confirmValueChange = { value ->
                                if (value == SwipeToDismissBoxValue.EndToStart && viewModel.isLocalBathroom(bathroom)) {
                                    viewModel.deleteBathroom(bathroom)
                                    true
                                } else false
                            }
                        )
                        if (viewModel.isLocalBathroom(bathroom)) {
                            SwipeToDismissBox(
                                state = dismissState,
                                backgroundContent = {
                                    Box(
                                        modifier = Modifier.fillMaxSize().padding(end = 16.dp),
                                        contentAlignment = Alignment.CenterEnd
                                    ) {
                                        Icon(Icons.Default.Delete, "Delete", tint = Color.Red)
                                    }
                                },
                                enableDismissFromStartToEnd = false
                            ) {
                                BathroomRowCard(bathroom, viewModel) { selectedBathroom = bathroom }
                            }
                        } else {
                            BathroomRowCard(bathroom, viewModel) { selectedBathroom = bathroom }
                        }
                    }
                }
            }
        }
    }

    selectedBathroom?.let { bathroom ->
        BathroomDetailSheet(bathroom = bathroom, viewModel = viewModel) { selectedBathroom = null }
    }
    if (showAdd) {
        AddBathroomSheet(viewModel = viewModel, onDismiss = { showAdd = false })
    }
}
