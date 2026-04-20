package com.gottago.app.ui

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*
import com.gottago.app.model.Bathroom

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(viewModel: com.gottago.app.viewmodel.BathroomViewModel) {
    val userLocation      by viewModel.userLocation.collectAsState()
    val filteredBathrooms = remember(viewModel.filteredBathrooms) { viewModel.filteredBathrooms }
    val sorted            = remember(viewModel.sortedByDistance) { viewModel.sortedByDistance }
    val isFetching        by viewModel.isFetchingExternal.collectAsState()
    val mapTypeIndex      by viewModel.mapTypeIndex.collectAsState()

    var selectedBathroom by remember { mutableStateOf<Bathroom?>(null) }
    var showAdd          by remember { mutableStateOf(false) }

    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(LatLng(40.7128, -74.0060), 14f)
    }
    var didCenter by remember { mutableStateOf(false) }

    // Auto-center on first location fix
    LaunchedEffect(userLocation) {
        val loc = userLocation ?: return@LaunchedEffect
        if (!didCenter) {
            didCenter = true
            cameraPositionState.animate(CameraUpdateFactory.newLatLngZoom(loc, 15f))
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("GottaGo", fontWeight = FontWeight.Bold) },
                actions = {
                    if (isFetching) CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp, color = Color(0xFF2ECC71))
                    Spacer(Modifier.width(8.dp))
                    IconButton(onClick = { showAdd = true }) {
                        Icon(Icons.Default.AddCircle, "Add", tint = Color(0xFF2ECC71))
                    }
                }
            )
        }
    ) { padding ->

        Column(
            modifier = Modifier
                .padding(padding)
                .verticalScroll(rememberScrollState())
        ) {
            // ── Windowed Map ──────────────────────────────────────────────────
            Box(
                modifier = Modifier
                    .padding(horizontal = 16.dp, vertical = 8.dp)
                    .fillMaxWidth()
                    .height(280.dp)
                    .clip(RoundedCornerShape(20.dp))
            ) {
                val mapType = when (mapTypeIndex) {
                    1    -> MapType.SATELLITE
                    2    -> MapType.HYBRID
                    else -> MapType.NORMAL
                }
                GoogleMap(
                    modifier = Modifier.fillMaxSize(),
                    cameraPositionState = cameraPositionState,
                    properties = MapProperties(isMyLocationEnabled = userLocation != null, mapType = mapType),
                    uiSettings = MapUiSettings(myLocationButtonEnabled = false, zoomControlsEnabled = false)
                ) {
                    filteredBathrooms.take(40).forEach { bathroom ->
                        val pinColor = when {
                            bathroom.isFavorite                         -> BitmapDescriptorFactory.HUE_ROSE
                            bathroom.fee.name == "FREE"                 -> BitmapDescriptorFactory.HUE_GREEN
                            bathroom.fee.name == "PAID"                 -> BitmapDescriptorFactory.HUE_ORANGE
                            else                                         -> BitmapDescriptorFactory.HUE_AZURE
                        }
                        MarkerInfoWindow(
                            state = MarkerState(LatLng(bathroom.latitude, bathroom.longitude)),
                            icon  = BitmapDescriptorFactory.defaultMarker(pinColor),
                            title = bathroom.name,
                            onClick = { selectedBathroom = bathroom; false }
                        )
                    }
                }

                // Locate-me button
                IconButton(
                    onClick = {
                        userLocation?.let { cameraPositionState.move(CameraUpdateFactory.newLatLngZoom(it, 15f)) }
                    },
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(10.dp)
                        .size(36.dp)
                ) {
                    Surface(shape = CircleShape, color = Color.White, shadowElevation = 4.dp) {
                        Box(contentAlignment = Alignment.Center, modifier = Modifier.fillMaxSize()) {
                            Icon(Icons.Default.MyLocation, "Locate me", tint = Color(0xFF3498DB), modifier = Modifier.size(20.dp))
                        }
                    }
                }
            }

            // ── Map Style Picker ──────────────────────────────────────────────
            Column(modifier = Modifier.padding(start = 16.dp, top = 12.dp)) {
                Text("Map Style", fontSize = 11.sp, color = Color.Gray, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(6.dp))
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    listOf("Standard" to Icons.Default.Map,
                           "Satellite" to Icons.Default.SatelliteAlt,
                           "Hybrid"    to Icons.Default.Layers).forEachIndexed { idx, (label, icon) ->
                        val selected = mapTypeIndex == idx
                        FilterChip(
                            selected    = selected,
                            onClick     = { viewModel.setMapTypeIndex(idx) },
                            label       = { Text(label, fontSize = 12.sp) },
                            leadingIcon = { Icon(icon, null, Modifier.size(14.dp)) },
                            colors      = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = Color(0xFF2ECC71),
                                selectedLabelColor     = Color.White,
                                selectedLeadingIconColor = Color.White
                            )
                        )
                    }
                }
            }

            // ── Filters ───────────────────────────────────────────────────────
            Column(modifier = Modifier.padding(start = 16.dp, top = 12.dp)) {
                Text("Filters", fontSize = 11.sp, color = Color.Gray, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(6.dp))
                Row(modifier = Modifier.horizontalScroll(rememberScrollState()).padding(end = 16.dp)) {
                    FilterChipsRow(viewModel)
                }
            }

            // ── Nearby Header ─────────────────────────────────────────────────
            Row(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Nearby Restrooms", fontWeight = FontWeight.Bold, fontSize = 18.sp, modifier = Modifier.weight(1f))
                if (isFetching) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp, color = Color(0xFF2ECC71))
                        Spacer(Modifier.width(4.dp))
                        Text("Updating…", fontSize = 11.sp, color = Color.Gray)
                    }
                }
            }

            // ── Nearby List ───────────────────────────────────────────────────
            if (sorted.isEmpty()) {
                Box(modifier = Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Default.SearchOff, null, modifier = Modifier.size(48.dp), tint = Color.LightGray)
                        Spacer(Modifier.height(8.dp))
                        Text("No restrooms found", color = Color.Gray)
                        Text("Try adjusting your filters", fontSize = 12.sp, color = Color.LightGray)
                    }
                }
            } else {
                Column(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    sorted.take(15).forEach { bathroom ->
                        BathroomRowCard(bathroom, viewModel) { selectedBathroom = bathroom }
                    }
                    Spacer(Modifier.height(16.dp))
                }
            }
        }
    }

    // Detail sheet
    selectedBathroom?.let { bathroom ->
        BathroomDetailSheet(bathroom = bathroom, viewModel = viewModel) {
            selectedBathroom = null
        }
    }

    // Add bathroom sheet
    if (showAdd) {
        AddBathroomSheet(viewModel = viewModel, onDismiss = { showAdd = false })
    }
}
