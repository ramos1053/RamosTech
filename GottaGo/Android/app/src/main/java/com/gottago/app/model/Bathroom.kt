package com.gottago.app.model

import java.util.UUID

enum class BathroomType(val displayName: String) {
    PUBLIC_FACILITY("Public"),
    RESTAURANT("Restaurant"),
    HOTEL("Hotel"),
    STORE("Store"),
    GAS_STATION("Gas Station"),
    PARK("Park"),
    OTHER("Other")
}

enum class FeeType(val displayName: String) {
    FREE("Free"),
    PAID("Paid"),
    UNKNOWN("Unknown")
}

data class Review(
    val id: String = UUID.randomUUID().toString(),
    val authorName: String,
    val rating: Double,      // 1–5
    val cleanliness: Double, // 1–5
    val comment: String,
    val date: Long = System.currentTimeMillis()
)

data class Bathroom(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val address: String,
    val latitude: Double,
    val longitude: Double,
    val type: BathroomType = BathroomType.PUBLIC_FACILITY,
    val fee: FeeType = FeeType.FREE,
    val isAccessible: Boolean = false,
    val isGenderNeutral: Boolean = false,
    val requiresPurchase: Boolean = false,
    val accessCode: String? = null,
    val notes: String = "",
    val hours: String = "",
    val isVerified: Boolean = false,
    val dateAdded: Long = System.currentTimeMillis(),
    var isFavorite: Boolean = false,
    val reviews: List<Review> = emptyList()
) {
    val averageRating: Double
        get() = if (reviews.isEmpty()) 0.0 else reviews.map { it.rating }.average()

    val averageCleanliness: Double
        get() = if (reviews.isEmpty()) 0.0 else reviews.map { it.cleanliness }.average()
}

// ──────────────────────────────────────────────────────────────────────────────
// Sample data (mirrors iOS Bathroom.sampleData)
// ──────────────────────────────────────────────────────────────────────────────
val sampleBathrooms = listOf(
    Bathroom(
        id = "sample-01",
        name = "Bryant Park Restrooms",
        address = "42nd St & 6th Ave, New York, NY",
        latitude = 40.7536,
        longitude = -73.9832,
        type = BathroomType.PUBLIC_FACILITY,
        fee = FeeType.FREE,
        isAccessible = true,
        isGenderNeutral = false,
        isVerified = true,
        hours = "7:00 AM – 11:00 PM",
        notes = "Well maintained. Attendant on duty most hours.",
        reviews = listOf(
            Review(authorName = "Alex", rating = 4.0, cleanliness = 4.5, comment = "Very clean!")
        )
    ),
    Bathroom(
        id = "sample-02",
        name = "Grand Central Terminal",
        address = "89 E 42nd St, New York, NY",
        latitude = 40.7527,
        longitude = -73.9772,
        type = BathroomType.PUBLIC_FACILITY,
        fee = FeeType.FREE,
        isAccessible = true,
        isVerified = true,
        hours = "5:30 AM – 2:00 AM",
        notes = "Lower level near the food court."
    ),
    Bathroom(
        id = "sample-03",
        name = "Starbucks – Times Square",
        address = "1585 Broadway, New York, NY",
        latitude = 40.7589,
        longitude = -73.9851,
        type = BathroomType.RESTAURANT,
        fee = FeeType.FREE,
        isAccessible = true,
        isGenderNeutral = true,
        requiresPurchase = true,
        accessCode = "1234",
        notes = "Purchase required. Ask staff for code.",
        hours = "5:00 AM – 11:00 PM"
    )
)
