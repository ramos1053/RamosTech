package com.gottago.app.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.gottago.app.model.Bathroom
import com.gottago.app.model.FeeType
import com.gottago.app.model.Review
import com.gottago.app.viewmodel.BathroomViewModel

// ──────────────────────────────────────────────────────────────────────────────
// Star rating row  (5 stars, color-graded)
// ──────────────────────────────────────────────────────────────────────────────

fun ratingColor(rating: Double): Color = when (rating.toInt()) {
    1    -> Color(0xFFE74C3C)
    2    -> Color(0xFFE67E22)
    3    -> Color(0xFFF39C12)
    4    -> Color(0xFF2ECC71)
    else -> Color(0xFF27AE60)
}

@Composable
fun StarRatingRow(rating: Double, modifier: Modifier = Modifier) {
    val color = ratingColor(rating)
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        repeat(5) { i ->
            Icon(
                imageVector    = if (i < rating.toInt()) Icons.Default.Star else Icons.Default.StarBorder,
                contentDescription = null,
                tint           = if (i < rating.toInt()) color else Color.LightGray,
                modifier       = Modifier.size(14.dp)
            )
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Fee color helper
// ──────────────────────────────────────────────────────────────────────────────

fun feeColor(fee: FeeType): Color = when (fee) {
    FeeType.FREE    -> Color(0xFF2ECC71)
    FeeType.PAID    -> Color(0xFFE67E22)
    FeeType.UNKNOWN -> Color(0xFF3498DB)
}

// ──────────────────────────────────────────────────────────────────────────────
// Bathroom row card
// ──────────────────────────────────────────────────────────────────────────────

@Composable
fun BathroomRowCard(
    bathroom: Bathroom,
    viewModel: BathroomViewModel,
    onClick: () -> Unit
) {
    val fc = feeColor(bathroom.fee)
    Card(
        onClick   = onClick,
        modifier  = Modifier.fillMaxWidth(),
        shape     = RoundedCornerShape(16.dp),
        elevation = CardDefaults.cardElevation(2.dp)
    ) {
        Row(
            modifier          = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Icon tile
            Surface(
                shape    = RoundedCornerShape(12.dp),
                color    = fc.copy(alpha = 0.15f),
                modifier = Modifier.size(54.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(Icons.Default.Wc, null, tint = fc, modifier = Modifier.size(26.dp))
                }
            }

            Spacer(Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(bathroom.name, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 1)
                    if (bathroom.isVerified)
                        Icon(Icons.Default.Verified, null, tint = Color(0xFF2ECC71), modifier = Modifier.size(13.dp))
                    if (bathroom.isFavorite)
                        Icon(Icons.Default.Favorite, null, tint = Color.Red, modifier = Modifier.size(13.dp))
                }
                if (bathroom.address.isNotEmpty())
                    Text(bathroom.address, fontSize = 12.sp, color = Color.Gray, maxLines = 1)

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(bathroom.fee.displayName, fontSize = 11.sp, color = fc, fontWeight = FontWeight.SemiBold)
                    if (bathroom.isAccessible)
                        Icon(Icons.Default.Accessible, null, tint = Color(0xFF3498DB), modifier = Modifier.size(13.dp))
                    if (bathroom.isGenderNeutral)
                        Icon(Icons.Default.People, null, tint = Color(0xFF9B59B6), modifier = Modifier.size(13.dp))
                    if (bathroom.requiresPurchase)
                        Icon(Icons.Default.ShoppingBag, null, tint = Color(0xFFE67E22), modifier = Modifier.size(13.dp))
                }
            }

            Column(horizontalAlignment = Alignment.End) {
                if (bathroom.averageRating > 0)
                    Text("%.1f".format(bathroom.averageRating), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                viewModel.distanceText(bathroom)?.let {
                    Text(it, fontSize = 11.sp, color = Color.Gray)
                }
            }
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Filter chips row
// ──────────────────────────────────────────────────────────────────────────────

@Composable
fun FilterChipsRow(viewModel: BathroomViewModel) {
    val freeOnly       by viewModel.filterFreeOnly.collectAsState()
    val accessibleOnly by viewModel.filterAccessibleOnly.collectAsState()
    val genderNeutral  by viewModel.filterGenderNeutral.collectAsState()

    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        FilterChip(selected = freeOnly, onClick = { viewModel.setFilterFreeOnly(!freeOnly) },
            label = { Text("Free") },
            leadingIcon = { Icon(Icons.Default.AttachMoney, null, Modifier.size(16.dp)) })
        FilterChip(selected = accessibleOnly, onClick = { viewModel.setFilterAccessibleOnly(!accessibleOnly) },
            label = { Text("Accessible") },
            leadingIcon = { Icon(Icons.Default.Accessible, null, Modifier.size(16.dp)) })
        FilterChip(selected = genderNeutral, onClick = { viewModel.setFilterGenderNeutral(!genderNeutral) },
            label = { Text("Neutral") },
            leadingIcon = { Icon(Icons.Default.People, null, Modifier.size(16.dp)) })
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Info tile (2-column grid in detail sheet)
// ──────────────────────────────────────────────────────────────────────────────

@Composable
fun InfoTile(icon: ImageVector, iconColor: Color, title: String, value: String, modifier: Modifier = Modifier) {
    Surface(shape = RoundedCornerShape(12.dp), color = MaterialTheme.colorScheme.surfaceVariant, modifier = modifier) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(icon, null, tint = iconColor, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(4.dp))
                Text(title, fontSize = 11.sp, color = Color.Gray)
            }
            Spacer(Modifier.height(4.dp))
            Text(value, fontWeight = FontWeight.Bold, fontSize = 14.sp)
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Banner row (purchase required, access code)
// ──────────────────────────────────────────────────────────────────────────────

@Composable
fun BannerRow(icon: ImageVector, color: Color, text: String) {
    Surface(shape = RoundedCornerShape(10.dp), color = color.copy(alpha = 0.1f), modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = color, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(8.dp))
            Text(text, fontSize = 13.sp, color = color)
        }
    }
}

// ──────────────────────────────────────────────────────────────────────────────
// Review card
// ──────────────────────────────────────────────────────────────────────────────

@Composable
fun ReviewCard(review: Review) {
    Surface(shape = RoundedCornerShape(12.dp), color = MaterialTheme.colorScheme.surfaceVariant, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(review.authorName, fontWeight = FontWeight.Bold)
                Spacer(Modifier.weight(1f))
                StarRatingRow(review.rating)
            }
            Text("Cleanliness: ${"%.1f".format(review.cleanliness)}/5", fontSize = 12.sp, color = Color.Gray)
            if (review.comment.isNotBlank())
                Text(review.comment, fontSize = 13.sp)
        }
    }
}
