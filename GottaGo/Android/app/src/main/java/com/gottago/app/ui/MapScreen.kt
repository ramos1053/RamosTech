package com.gottago.app.ui

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.model.BitmapDescriptorFactory
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*
import com.gottago.app.model.Bathroom
import com.gottago.app.viewmodel.BathroomViewModel

@Composable
fun MapScreen(viewModel: BathroomViewModel) {
    val userLocation      by viewModel.userLocation.collectAsState()
    val filteredBathrooms = viewModel.filteredBathrooms
    val mapTypeIndex      by viewModel.mapTypeIndex.collectAsState()
    var selectedBathroom  by remember { mutableStateOf<Bathroom?>(null) }
    var showAdd           by remember { mutableStateOf(false) }

    val cameraPositionState = rememberCameraPositionState {
        position = CameraPosition.fromLatLngZoom(LatLng(40.7128, -74.0060), 14f)
    }
    var didCenter by remember { mutableStateOf(false) }

    LaunchedEffect(userLocation) {
        val loc = userLocation ?: return@LaunchedEffect
        if (!didCenter) { didCenter = true; cameraPositionState.animate(CameraUpdateFactory.newLatLngZoom(loc, 15f)) }
    }

    val mapType = when (mapTypeIndex) { 1 -> MapType.SATELLITE; 2 -> MapType.HYBRID; else -> MapType.NORMAL }

    Box(modifier = Modifier.fillMaxSize()) {
        GoogleMap(
            modifier = Modifier.fillMaxSize(),
            cameraPositionState = cameraPositionState,
            properties = MapProperties(isMyLocationEnabled = userLocation != null, mapType = mapType),
            uiSettings = MapUiSettings(myLocationButtonEnabled = false, zoomControlsEnabled = false)
        ) {
            filteredBathrooms.forEach { bathroom ->
                val hue = when {
                    bathroom.isFavorite         -> BitmapDescriptorFactory.HUE_ROSE
                    bathroom.fee.name == "FREE" -> BitmapDescriptorFactory.HUE_GREEN
                    bathroom.fee.name == "PAID" -> BitmapDescriptorFactory.HUE_ORANGE
                    else                        -> BitmapDescriptorFactory.HUE_AZURE
                }
                MarkerInfoWindow(
                    state = MarkerState(LatLng(bathroom.latitude, bathroom.longitude)),
                    icon  = BitmapDescriptorFactory.defaultMarker(hue),
                    title = bathroom.name,
                    snippet = bathroom.fee.displayName,
                    onClick = { selectedBathroom = bathroom; false }
                )
            }
        }

        // Bottom overlay
        Column(
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Filter chips
            Surface(shadowElevation = 4.dp, shape = CircleShape, color = MaterialTheme.colorScheme.surface) {
                Row(modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp).horizontalScroll(rememberScrollState())) {
                    FilterChipsRow(viewModel)
                }
            }
        }

        // Floating action buttons
        Column(
            modifier = Modifier.align(Alignment.BottomEnd).padding(end = 16.dp, bottom = 80.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            SmallFloatingActionButton(
                onClick = { userLocation?.let { cameraPositionState.move(CameraUpdateFactory.newLatLngZoom(it, 15f)) } },
                containerColor = Color.White
            ) { Icon(Icons.Default.MyLocation, "Locate", tint = Color(0xFF3498DB)) }

            FloatingActionButton(
                onClick = { showAdd = true },
                containerColor = Color(0xFF2ECC71)
            ) { Icon(Icons.Default.Add, "Add", tint = Color.White) }
        }

        // Map style switcher (top right)
        Column(modifier = Modifier.align(Alignment.TopEnd).padding(top = 8.dp, end = 12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            listOf(Icons.Default.Map to 0, Icons.Default.SatelliteAlt to 1, Icons.Default.Layers to 2).forEach { (icon, idx) ->
                SmallFloatingActionButton(
                    onClick = { viewModel.setMapTypeIndex(idx) },
                    containerColor = if (mapTypeIndex == idx) Color(0xFF2ECC71) else Color.White
                ) { Icon(icon, null, tint = if (mapTypeIndex == idx) Color.White else Color.DarkGray, modifier = Modifier.size(18.dp)) }
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
