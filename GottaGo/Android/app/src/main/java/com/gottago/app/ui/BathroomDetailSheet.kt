package com.gottago.app.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.*
import com.gottago.app.model.Bathroom
import com.gottago.app.model.FeeType
import com.gottago.app.model.Review
import com.gottago.app.viewmodel.BathroomViewModel
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BathroomDetailSheet(
    bathroom: Bathroom,
    viewModel: BathroomViewModel,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val isFavorite by remember { derivedStateOf { viewModel.isFavorite(bathroom) } }
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showAddReview    by remember { mutableStateOf(false) }
    val fc = feeColor(bathroom.fee)

    ModalBottomSheet(onDismissRequest = onDismiss, modifier = Modifier.fillMaxHeight(0.92f)) {

        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Restroom Details", fontWeight = FontWeight.Bold) },
                    navigationIcon = {
                        IconButton(onClick = onDismiss) {
                            Icon(Icons.Default.Close, "Close")
                        }
                    },
                    actions = {
                        if (viewModel.isLocalBathroom(bathroom)) {
                            IconButton(onClick = { showDeleteDialog = true }) {
                                Icon(Icons.Default.Delete, "Delete", tint = Color.Red)
                            }
                        }
                        IconButton(onClick = { viewModel.toggleFavorite(bathroom) }) {
                            Icon(
                                if (isFavorite) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                                "Favorite", tint = Color.Red
                            )
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
                // Mini Map
                val cameraPos = rememberCameraPositionState {
                    position = CameraPosition.fromLatLngZoom(LatLng(bathroom.latitude, bathroom.longitude), 16f)
                }
                GoogleMap(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp),
                    cameraPositionState = cameraPos,
                    uiSettings = MapUiSettings(zoomControlsEnabled = false, scrollGesturesEnabled = false)
                ) {
                    Marker(state = MarkerState(LatLng(bathroom.latitude, bathroom.longitude)), title = bathroom.name)
                }

                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {

                    // Header
                    Column {
                        Row(verticalAlignment = Alignment.Top) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(bathroom.name, fontWeight = FontWeight.Bold, fontSize = 20.sp)
                                if (bathroom.address.isNotEmpty())
                                    Text(bathroom.address, fontSize = 13.sp, color = Color.Gray)
                            }
                            if (bathroom.isVerified) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Verified, null, tint = Color(0xFF2ECC71), modifier = Modifier.size(14.dp))
                                    Spacer(Modifier.width(2.dp))
                                    Text("Verified", fontSize = 11.sp, color = Color(0xFF2ECC71), fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                        if (bathroom.averageRating > 0) {
                            Spacer(Modifier.height(4.dp))
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                StarRatingRow(bathroom.averageRating)
                                Text("%.1f".format(bathroom.averageRating), fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                Text("(${bathroom.reviews.size} review${if (bathroom.reviews.size == 1) "" else "s"})", fontSize = 12.sp, color = Color.Gray)
                            }
                        }
                    }

                    // Info Grid
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        InfoTile(Icons.Default.AttachMoney, fc, "Cost", bathroom.fee.displayName, Modifier.weight(1f))
                        InfoTile(Icons.Default.Schedule, Color(0xFF8E44AD), "Hours",
                            bathroom.hours.ifEmpty { "Unknown" }, Modifier.weight(1f))
                    }
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        InfoTile(Icons.Default.Accessible, if (bathroom.isAccessible) Color(0xFF3498DB) else Color.Gray,
                            "Accessible", if (bathroom.isAccessible) "Yes" else "No", Modifier.weight(1f))
                        InfoTile(Icons.Default.People, if (bathroom.isGenderNeutral) Color(0xFF9B59B6) else Color.Gray,
                            "Gender Neutral", if (bathroom.isGenderNeutral) "Yes" else "No", Modifier.weight(1f))
                    }

                    // Banners
                    if (bathroom.requiresPurchase)
                        BannerRow(Icons.Default.ShoppingBag, Color(0xFFE67E22), "Purchase required to use restroom")
                    if (!bathroom.accessCode.isNullOrEmpty())
                        BannerRow(Icons.Default.Lock, Color(0xFFF39C12), "Access code: ${bathroom.accessCode}")

                    // Average cleanliness
                    if (bathroom.reviews.isNotEmpty()) {
                        Surface(shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surfaceVariant, modifier = Modifier.fillMaxWidth()) {
                            Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.AutoAwesome, null, tint = Color(0xFF2ECC71), modifier = Modifier.size(16.dp))
                                Spacer(Modifier.width(6.dp))
                                Text("Avg. Cleanliness", fontSize = 13.sp, color = Color.Gray, modifier = Modifier.weight(1f))
                                StarRatingRow(bathroom.averageCleanliness)
                                Spacer(Modifier.width(4.dp))
                                Text("%.1f".format(bathroom.averageCleanliness), fontWeight = FontWeight.Bold, fontSize = 13.sp)
                            }
                        }
                    }

                    // Notes
                    if (bathroom.notes.isNotEmpty()) {
                        Column {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Notes, null, modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(4.dp))
                                Text("Notes", fontWeight = FontWeight.Bold)
                            }
                            Spacer(Modifier.height(4.dp))
                            Text(bathroom.notes, fontSize = 13.sp, color = Color.Gray)
                        }
                    }

                    Divider()

                    // Action Buttons
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(
                            onClick = {
                                val uri = Uri.parse("google.navigation:q=${bathroom.latitude},${bathroom.longitude}&mode=w")
                                context.startActivity(Intent(Intent.ACTION_VIEW, uri).apply {
                                    setPackage("com.google.android.apps.maps")
                                })
                            },
                            modifier = Modifier.weight(1f),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2ECC71))
                        ) {
                            Icon(Icons.Default.Directions, null, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("Directions")
                        }
                        OutlinedButton(
                            onClick = {
                                val uri = Uri.parse("geo:${bathroom.latitude},${bathroom.longitude}?q=${bathroom.latitude},${bathroom.longitude}(${Uri.encode(bathroom.name)})")
                                context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Icon(Icons.Default.Map, null, modifier = Modifier.size(18.dp))
                            Spacer(Modifier.width(6.dp))
                            Text("Open Map")
                        }
                    }

                    Divider()

                    // Reviews
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Reviews", fontWeight = FontWeight.Bold, fontSize = 16.sp, modifier = Modifier.weight(1f))
                        TextButton(onClick = { showAddReview = true }) {
                            Icon(Icons.Default.Edit, null, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(4.dp))
                            Text("Write a Review", color = Color(0xFF2ECC71))
                        }
                    }

                    if (bathroom.reviews.isEmpty()) {
                        Text("No reviews yet — be the first!", fontSize = 13.sp, color = Color.Gray)
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            bathroom.reviews.forEach { ReviewCard(it) }
                        }
                    }

                    Spacer(Modifier.height(24.dp))
                }
            }
        }
    }

    // Delete confirmation
    if (showDeleteDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteDialog = false },
            title = { Text("Delete \"${bathroom.name}\"?") },
            text  = { Text("This will permanently remove this restroom from your list.") },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.deleteBathroom(bathroom)
                    showDeleteDialog = false
                    onDismiss()
                }) { Text("Delete", color = Color.Red) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteDialog = false }) { Text("Cancel") }
            }
        )
    }

    // Add review sheet
    if (showAddReview) {
        AddReviewSheet(bathroomId = bathroom.id, viewModel = viewModel) {
            showAddReview = false
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Add Review Sheet
// ──────────────────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddReviewSheet(bathroomId: String, viewModel: BathroomViewModel, onDismiss: () -> Unit) {
    var authorName  by remember { mutableStateOf("") }
    var rating      by remember { mutableFloatStateOf(3f) }
    var cleanliness by remember { mutableFloatStateOf(3f) }
    var comment     by remember { mutableStateOf("") }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Write a Review", fontWeight = FontWeight.Bold, fontSize = 18.sp)

            OutlinedTextField(value = authorName, onValueChange = { authorName = it },
                label = { Text("Your name (optional)") }, modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("Anonymous") })

            Text("Overall Rating: ${"%.0f".format(rating)}/5", fontWeight = FontWeight.SemiBold)
            Slider(value = rating, onValueChange = { rating = it }, valueRange = 1f..5f, steps = 3,
                colors = SliderDefaults.colors(thumbColor = Color(0xFF2ECC71), activeTrackColor = Color(0xFF2ECC71)))

            Text("Cleanliness: ${"%.0f".format(cleanliness)}/5", fontWeight = FontWeight.SemiBold)
            Slider(value = cleanliness, onValueChange = { cleanliness = it }, valueRange = 1f..5f, steps = 3,
                colors = SliderDefaults.colors(thumbColor = Color(0xFF2ECC71), activeTrackColor = Color(0xFF2ECC71)))

            OutlinedTextField(value = comment, onValueChange = { comment = it },
                label = { Text("Comment") }, modifier = Modifier.fillMaxWidth().height(100.dp),
                maxLines = 4)

            Button(
                onClick = {
                    viewModel.addReview(bathroomId, Review(
                        authorName  = authorName.ifBlank { "Anonymous" },
                        rating      = rating.toDouble(),
                        cleanliness = cleanliness.toDouble(),
                        comment     = comment
                    ))
                    onDismiss()
                },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2ECC71))
            ) { Text("Submit Review") }

            Spacer(Modifier.height(16.dp))
        }
    }
}
