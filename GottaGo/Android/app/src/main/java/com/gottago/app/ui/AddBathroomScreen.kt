package com.gottago.app.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectableGroup
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
import com.gottago.app.model.*
import com.gottago.app.service.ToiletDataService
import com.gottago.app.viewmodel.BathroomViewModel
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddBathroomSheet(
    viewModel: BathroomViewModel,
    prefilledCoordinate: LatLng? = null,
    onDismiss: () -> Unit
) {
    val scope   = rememberCoroutineScope()
    val userLoc by viewModel.userLocation.collectAsState()

    // Form state
    var name            by remember { mutableStateOf("") }
    var address         by remember { mutableStateOf("") }
    var type            by remember { mutableStateOf(BathroomType.PUBLIC_FACILITY) }
    var fee             by remember { mutableStateOf(FeeType.FREE) }
    var isAccessible    by remember { mutableStateOf(false) }
    var isGenderNeutral by remember { mutableStateOf(false) }
    var requiresPurchase by remember { mutableStateOf(false) }
    var accessCode      by remember { mutableStateOf("") }
    var notes           by remember { mutableStateOf("") }
    var hours           by remember { mutableStateOf("") }
    var useCurrentLoc   by remember { mutableStateOf(prefilledCoordinate == null) }
    var pickedLatLng    by remember { mutableStateOf(prefilledCoordinate ?: userLoc ?: LatLng(40.7128, -74.0060)) }
    var shareWithRefuge by remember { mutableStateOf(false) }

    enum class RefugeStatus { IDLE, SUBMITTING, SUCCESS, FAILED }
    var refugeStatus by remember { mutableStateOf(RefugeStatus.IDLE) }

    val formValid = name.isNotBlank() && address.isNotBlank() &&
        (useCurrentLoc && userLoc != null || !useCurrentLoc)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        modifier = Modifier.fillMaxHeight(0.95f)
    ) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text("Add a Restroom", fontWeight = FontWeight.Bold) },
                    navigationIcon = { IconButton(onClick = onDismiss) { Icon(Icons.Default.Close, "Cancel") } },
                    actions = {
                        TextButton(
                            onClick = {
                                val coord = if (useCurrentLoc) userLoc ?: return@TextButton else pickedLatLng
                                val bathroom = Bathroom(
                                    name            = name.trim(),
                                    address         = address.trim(),
                                    latitude        = coord.latitude,
                                    longitude       = coord.longitude,
                                    type            = type,
                                    fee             = fee,
                                    isAccessible    = isAccessible,
                                    isGenderNeutral = isGenderNeutral,
                                    requiresPurchase = requiresPurchase,
                                    accessCode      = accessCode.ifBlank { null },
                                    notes           = notes,
                                    hours           = hours,
                                    isVerified      = false
                                )
                                viewModel.addBathroom(bathroom)
                                if (!shareWithRefuge) { onDismiss(); return@TextButton }
                                refugeStatus = RefugeStatus.SUBMITTING
                                scope.launch {
                                    val ok = ToiletDataService.submitToRefugeRestrooms(bathroom)
                                    refugeStatus = if (ok) RefugeStatus.SUCCESS else RefugeStatus.FAILED
                                    kotlinx.coroutines.delay(1500)
                                    onDismiss()
                                }
                            },
                            enabled = formValid && refugeStatus != RefugeStatus.SUBMITTING
                        ) { Text("Add", color = if (formValid) Color(0xFF2ECC71) else Color.Gray, fontWeight = FontWeight.Bold) }
                    }
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(0.dp)
            ) {
                // ── Basic Info ─────────────────────────────────────────────────
                SectionHeader("Basic Info")
                OutlinedTextField(value = name, onValueChange = { name = it },
                    label = { Text("Name *") }, modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(value = address, onValueChange = { address = it },
                    label = { Text("Address / Landmark *") }, modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))

                // Category picker
                Text("Category", fontSize = 12.sp, color = Color.Gray)
                var typeMenuExpanded by remember { mutableStateOf(false) }
                ExposedDropdownMenuBox(expanded = typeMenuExpanded, onExpandedChange = { typeMenuExpanded = it }) {
                    OutlinedTextField(
                        value = type.displayName,
                        onValueChange = {},
                        readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(typeMenuExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor()
                    )
                    ExposedDropdownMenu(expanded = typeMenuExpanded, onDismissRequest = { typeMenuExpanded = false }) {
                        BathroomType.entries.forEach { t ->
                            DropdownMenuItem(text = { Text(t.displayName) }, onClick = { type = t; typeMenuExpanded = false })
                        }
                    }
                }
                Spacer(Modifier.height(12.dp))

                // ── Location ───────────────────────────────────────────────────
                SectionHeader("Location")
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Use my current location", modifier = Modifier.weight(1f))
                    Switch(checked = useCurrentLoc, onCheckedChange = { useCurrentLoc = it })
                }
                if (!useCurrentLoc) {
                    Spacer(Modifier.height(8.dp))
                    val camState = rememberCameraPositionState {
                        position = CameraPosition.fromLatLngZoom(pickedLatLng, 15f)
                    }
                    GoogleMap(
                        modifier = Modifier.fillMaxWidth().height(180.dp),
                        cameraPositionState = camState,
                        onMapClick = { pickedLatLng = it },
                        properties = MapProperties(isMyLocationEnabled = userLoc != null),
                        uiSettings = MapUiSettings(zoomControlsEnabled = false)
                    ) {
                        Marker(state = MarkerState(pickedLatLng))
                    }
                    Text("Tap the map to move the pin", fontSize = 11.sp, color = Color.Gray)
                    Text("%.5f,  %.5f".format(pickedLatLng.latitude, pickedLatLng.longitude),
                        fontSize = 11.sp, fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace)
                } else if (userLoc == null) {
                    Text("Location unavailable — enable Location Services", fontSize = 12.sp, color = Color(0xFFE67E22))
                } else {
                    Text("Will use your current GPS position", fontSize = 12.sp, color = Color(0xFF2ECC71))
                }
                Spacer(Modifier.height(12.dp))

                // ── Cost & Access ──────────────────────────────────────────────
                SectionHeader("Cost & Access")
                Text("Fee", fontSize = 12.sp, color = Color.Gray)
                Row(modifier = Modifier.selectableGroup(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FeeType.entries.forEach { f ->
                        FilterChip(selected = fee == f, onClick = { fee = f }, label = { Text(f.displayName) })
                    }
                }
                Spacer(Modifier.height(6.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Wheelchair Accessible", Modifier.weight(1f))
                    Switch(checked = isAccessible, onCheckedChange = { isAccessible = it })
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Gender Neutral / All-Gender", Modifier.weight(1f))
                    Switch(checked = isGenderNeutral, onCheckedChange = {
                        isGenderNeutral = it
                        if (it) shareWithRefuge = true
                    })
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Purchase Required to Use", Modifier.weight(1f))
                    Switch(checked = requiresPurchase, onCheckedChange = { requiresPurchase = it })
                }
                if (requiresPurchase || fee == FeeType.PAID) {
                    Spacer(Modifier.height(6.dp))
                    OutlinedTextField(value = accessCode, onValueChange = { accessCode = it },
                        label = { Text("Access Code (if known)") }, modifier = Modifier.fillMaxWidth())
                }
                Spacer(Modifier.height(12.dp))

                // ── Hours & Notes ──────────────────────────────────────────────
                SectionHeader("Hours")
                OutlinedTextField(value = hours, onValueChange = { hours = it },
                    label = { Text("e.g. 8 AM – 10 PM  or  24 hours") }, modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                SectionHeader("Notes")
                OutlinedTextField(value = notes, onValueChange = { notes = it },
                    label = { Text("Directions, tips…") }, modifier = Modifier.fillMaxWidth().height(100.dp), maxLines = 4)
                Spacer(Modifier.height(12.dp))

                // ── Community ──────────────────────────────────────────────────
                SectionHeader("Community")
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Share with Refuge Restrooms", Modifier.weight(1f))
                    Switch(checked = shareWithRefuge, onCheckedChange = { shareWithRefuge = it })
                }
                if (shareWithRefuge) {
                    Text("Submits to refugerestrooms.org — a worldwide community database of gender-neutral and accessible restrooms.",
                        fontSize = 11.sp, color = Color.Gray)
                }
                when (refugeStatus) {
                    RefugeStatus.SUBMITTING -> Row(verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        Spacer(Modifier.width(6.dp))
                        Text("Submitting to Refuge Restrooms…", fontSize = 12.sp, color = Color.Gray)
                    }
                    RefugeStatus.SUCCESS -> Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF2ECC71), modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Submitted to Refuge Restrooms!", fontSize = 12.sp, color = Color(0xFF2ECC71))
                    }
                    RefugeStatus.FAILED -> Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Warning, null, tint = Color(0xFFE67E22), modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Submission failed — saved locally only.", fontSize = 12.sp, color = Color(0xFFE67E22))
                    }
                    else -> Unit
                }
                Spacer(Modifier.height(32.dp))
            }
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(title, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(top = 4.dp, bottom = 4.dp))
    Divider(color = MaterialTheme.colorScheme.outlineVariant)
    Spacer(Modifier.height(8.dp))
}
