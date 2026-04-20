package com.gottago.app.service

import com.google.gson.Gson
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import com.gottago.app.model.*
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.net.URLEncoder
import java.util.concurrent.TimeUnit

object ToiletDataService {

    private val client = OkHttpClient.Builder()
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(35, TimeUnit.SECONDS)
        .build()
    private val gson = Gson()

    // ──────────────────────────────────────────────────────────────────────────
    // Overpass / OpenStreetMap
    // ──────────────────────────────────────────────────────────────────────────

    suspend fun fetchOverpassToilets(
        lat: Double, lng: Double, radiusDegrees: Double = 0.045
    ): List<Bathroom> = withContext(Dispatchers.IO) {
        val south = lat - radiusDegrees; val north = lat + radiusDegrees
        val west  = lng - radiusDegrees; val east  = lng + radiusDegrees
        val bb    = "$south,$west,$north,$east"

        val query = """
            [out:json][timeout:30];
            (
              node["amenity"="toilets"]($bb);
              way["amenity"="toilets"]($bb);
              node["toilets"="yes"]($bb);
              way["toilets"="yes"]($bb);
            );
            out center 100;
        """.trimIndent()

        val body = ("data=" + URLEncoder.encode(query, "UTF-8"))
            .toRequestBody("application/x-www-form-urlencoded".toMediaType())
        val request = Request.Builder()
            .url("https://overpass-api.de/api/interpreter")
            .post(body)
            .build()

        try {
            val response = client.newCall(request).execute()
            val json = gson.fromJson(response.body?.string(), JsonObject::class.java)
            val elements = json?.getAsJsonArray("elements") ?: return@withContext emptyList()
            elements.mapNotNull { overpassToBathroom(it.asJsonObject) }
        } catch (e: Exception) {
            println("Overpass error: ${e.message}")
            emptyList()
        }
    }

    private fun overpassToBathroom(el: JsonObject): Bathroom? {
        val id = el["id"]?.asLong ?: return null

        val lat: Double
        val lng: Double
        if (el.has("lat") && el.has("lon")) {
            lat = el["lat"].asDouble; lng = el["lon"].asDouble
        } else {
            val center = el["center"]?.asJsonObject ?: return null
            lat = center["lat"].asDouble; lng = center["lon"].asDouble
        }

        val tags = el["tags"]?.asJsonObject
        val amenity = tags?.get("amenity")?.asString ?: ""
        val isDedicated = amenity == "toilets"

        val (type, requiresPurchase) = if (isDedicated) {
            BathroomType.PUBLIC_FACILITY to false
        } else {
            osmVenueType(tags)
        }

        val name = if (isDedicated) {
            tags?.get("name")?.asString ?: tags?.get("description")?.asString ?: "Public Toilet"
        } else {
            val venueName = tags?.get("name")?.asString
            if (!venueName.isNullOrBlank()) "$venueName – Restroom"
            else "${type.displayName} Restroom"
        }

        val fee = when (tags?.get("fee")?.asString) {
            "no", "free" -> FeeType.FREE
            "yes"        -> FeeType.PAID
            else         -> if (isDedicated) FeeType.UNKNOWN else FeeType.FREE
        }
        val accessible    = tags?.get("wheelchair")?.asString.let { it == "yes" || it == "designated" }
        val genderNeutral = tags?.get("unisex")?.asString == "yes"
        val hours         = tags?.get("opening_hours")?.asString ?: ""
        val access        = tags?.get("access")?.asString ?: ""
        var notes         = if (access.isEmpty()) "" else "Access: $access"
        if (requiresPurchase) notes = if (notes.isEmpty()) "May require a purchase." else "$notes May require a purchase."

        val idHex   = id.toString(16).padStart(12, '0').uppercase()
        val uuidStr = "4F534D30-0000-4000-8000-$idHex"

        return Bathroom(
            id = uuidStr,
            name = name,
            address = "",
            latitude = lat,
            longitude = lng,
            type = type,
            fee = fee,
            isAccessible = accessible,
            isGenderNeutral = genderNeutral,
            requiresPurchase = requiresPurchase,
            notes = notes,
            hours = hours,
            isVerified = true
        )
    }

    private fun osmVenueType(tags: JsonObject?): Pair<BathroomType, Boolean> {
        val amenity = tags?.get("amenity")?.asString ?: ""
        val tourism  = tags?.get("tourism")?.asString ?: ""
        val shop     = tags?.get("shop")?.asString ?: ""
        val leisure  = tags?.get("leisure")?.asString ?: ""

        return when (amenity) {
            "fuel"                                                              -> BathroomType.GAS_STATION to false
            "restaurant","fast_food","cafe","bar","pub","food_court","biergarten","ice_cream"
                                                                                -> BathroomType.RESTAURANT  to true
            "hospital","clinic","doctors","pharmacy","dentist",
            "library","community_centre","arts_centre","theatre","cinema",
            "ferry_terminal","bus_station","airport"                            -> BathroomType.PUBLIC_FACILITY to false
            "shopping_mall"                                                     -> BathroomType.STORE to false
            "supermarket","convenience"                                         -> BathroomType.STORE to true
            else -> when (tourism) {
                "hotel","motel","hostel","guest_house","apartment","chalet","camp_site"
                    -> BathroomType.HOTEL to false
                else -> when {
                    shop.isNotEmpty() -> BathroomType.STORE to true
                    leisure in listOf("park","recreation_ground","garden","nature_reserve","dog_park","playground")
                        -> BathroomType.PARK to false
                    else -> BathroomType.OTHER to false
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Refuge Restrooms
    // ──────────────────────────────────────────────────────────────────────────

    suspend fun fetchRefugeRestrooms(lat: Double, lng: Double): List<Bathroom> =
        withContext(Dispatchers.IO) {
            val url = "https://www.refugerestrooms.org/api/v1/restrooms/by_location.json" +
                "?lat=$lat&lng=$lng&per_page=20&accessible=false"
            val request = Request.Builder().url(url).build()
            try {
                val response = client.newCall(request).execute()
                val arr = gson.fromJson(response.body?.string(), JsonArray::class.java) ?: return@withContext emptyList()
                arr.mapNotNull { refugeToBathroom(it.asJsonObject) }
            } catch (e: Exception) {
                println("Refuge error: ${e.message}")
                emptyList()
            }
        }

    private fun refugeToBathroom(obj: JsonObject): Bathroom? {
        val bLat = obj["latitude"]?.asDouble?.takeIf { it != 0.0 } ?: return null
        val bLng = obj["longitude"]?.asDouble?.takeIf { it != 0.0 } ?: return null
        val id   = obj["id"]?.asInt ?: 0
        val idHex   = Math.abs(id).toLong().toString(16).padStart(12, '0').uppercase()
        val uuidStr = "52465547-0000-4000-8000-$idHex"

        val rawName = obj["name"]?.asString?.trim() ?: ""
        val name    = rawName.ifEmpty { "Refuge Restroom" }
        val address = listOfNotNull(
            obj["street"]?.asString?.trim()?.ifEmpty { null },
            obj["city"]?.asString?.trim()?.ifEmpty { null },
            obj["state"]?.asString?.trim()?.ifEmpty { null },
            obj["country"]?.asString?.trim()?.ifEmpty { null }
        ).joinToString(", ")

        return Bathroom(
            id = uuidStr,
            name = name,
            address = address,
            latitude = bLat,
            longitude = bLng,
            fee = FeeType.FREE,
            isAccessible = obj["accessible"]?.asBoolean ?: false,
            isGenderNeutral = true,
            notes = obj["directions"]?.asString ?: "",
            isVerified = true
        )
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Great British Toilet Map (GraphQL)
    // ──────────────────────────────────────────────────────────────────────────

    suspend fun fetchGBPTM(lat: Double, lng: Double, radiusMeters: Int = 5000): List<Bathroom> =
        withContext(Dispatchers.IO) {
            val bodyJson = """{"query":"query NearbyLoos(${'$'}lat:Float!,${'$'}lng:Float!,${'$'}radius:Int!){loosByProximity(lat:${'$'}lat,lng:${'$'}lng,radius:${'$'}radius){id name accessible allGender noPayment openingTimes removalReason location{lat lng}}}","variables":{"lat":$lat,"lng":$lng,"radius":$radiusMeters}}"""
            val body = bodyJson.toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url("https://api.toiletmap.org.uk/graphql")
                .post(body)
                .build()
            try {
                val response = client.newCall(request).execute()
                val json = gson.fromJson(response.body?.string(), JsonObject::class.java)
                val loos = json?.getAsJsonObject("data")
                    ?.getAsJsonArray("loosByProximity") ?: return@withContext emptyList()
                loos.mapNotNull { gbptmToBathroom(it.asJsonObject) }
            } catch (e: Exception) {
                println("GBPTM error: ${e.message}")
                emptyList()
            }
        }

    private fun gbptmToBathroom(obj: JsonObject): Bathroom? {
        if (!obj["removalReason"]?.isJsonNull!!) return null // skip removed loos
        val loc = obj["location"]?.asJsonObject ?: return null
        val bLat = loc["lat"]?.asDouble ?: return null
        val bLng = loc["lng"]?.asDouble ?: return null
        val rawId   = obj["id"]?.asString ?: ""
        val hexPart = rawId.filter { it.isLetterOrDigit() }.take(12).padEnd(12, '0').uppercase()
        val uuidStr = "47425054-0000-4000-8000-$hexPart"
        val name    = obj["name"]?.asString?.trim()?.ifEmpty { null } ?: "Public Toilet"
        val noPayment = obj["noPayment"]?.takeIf { !it.isJsonNull }?.asBoolean
        val fee = when (noPayment) {
            true  -> FeeType.FREE
            false -> FeeType.PAID
            null  -> FeeType.UNKNOWN
        }
        return Bathroom(
            id = uuidStr,
            name = name,
            latitude = bLat,
            longitude = bLng,
            fee = fee,
            isAccessible = obj["accessible"]?.takeIf { !it.isJsonNull }?.asBoolean ?: false,
            isGenderNeutral = obj["allGender"]?.takeIf { !it.isJsonNull }?.asBoolean ?: false,
            hours = obj["openingTimes"]?.takeIf { !it.isJsonNull }?.asString ?: "",
            isVerified = true
        )
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Australia National Toilet Map
    // ──────────────────────────────────────────────────────────────────────────

    suspend fun fetchAustraliaToilets(lat: Double, lng: Double, maxResults: Int = 50): List<Bathroom> =
        withContext(Dispatchers.IO) {
            val url = "https://www.toiletmap.gov.au/Home/GetNearestToilets" +
                "?Latitude=$lat&Longitude=$lng&MaxNumber=$maxResults&Radius=5"
            val request = Request.Builder()
                .url(url)
                .header("User-Agent", "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36")
                .build()
            try {
                val response = client.newCall(request).execute()
                val arr = gson.fromJson(response.body?.string(), JsonArray::class.java) ?: return@withContext emptyList()
                arr.mapNotNull { ausToiletToBathroom(it.asJsonObject) }
            } catch (e: Exception) {
                println("Australia error: ${e.message}")
                emptyList()
            }
        }

    private fun ausToiletToBathroom(obj: JsonObject): Bathroom? {
        val bLat = obj["Latitude"]?.takeIf { !it.isJsonNull }?.asDouble?.takeIf { it != 0.0 } ?: return null
        val bLng = obj["Longitude"]?.takeIf { !it.isJsonNull }?.asDouble?.takeIf { it != 0.0 } ?: return null
        val toiletId = obj["ToiletID"]?.takeIf { !it.isJsonNull }?.asInt ?: 0
        val idHex   = Math.abs(toiletId).toLong().toString(16).padStart(12, '0').uppercase()
        val uuidStr = "41555354-0000-4000-8000-$idHex"

        val name = obj["Name"]?.takeIf { !it.isJsonNull }?.asString?.trim()?.ifEmpty { null } ?: "Public Toilet"
        val address = listOfNotNull(
            obj["Address1"]?.takeIf { !it.isJsonNull }?.asString?.trim()?.ifEmpty { null },
            obj["Town"]?.takeIf { !it.isJsonNull }?.asString?.trim()?.ifEmpty { null },
            obj["State"]?.takeIf { !it.isJsonNull }?.asString?.trim()?.ifEmpty { null },
            obj["Postcode"]?.takeIf { !it.isJsonNull }?.asString?.trim()?.ifEmpty { null }
        ).joinToString(", ")

        fun str(key: String) = obj[key]?.takeIf { !it.isJsonNull }?.asString ?: ""
        val accessible    = str("AccessibleMale") == "Yes" || str("AccessibleFemale") == "Yes" || str("AccessibleUnisex") == "Yes"
        val genderNeutral = str("Unisex") == "Yes"
        val fee           = if (str("PayToilet") == "Yes") FeeType.PAID else FeeType.FREE
        val notes         = buildList {
            if (str("BabyChange") == "Yes") add("Baby change available.")
            str("Notes").takeIf { it.isNotEmpty() }?.let { add(it) }
        }.joinToString(" ")

        return Bathroom(
            id = uuidStr,
            name = name,
            address = address,
            latitude = bLat,
            longitude = bLng,
            fee = fee,
            isAccessible = accessible,
            isGenderNeutral = genderNeutral,
            notes = notes,
            hours = str("OpeningHours"),
            isVerified = true
        )
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Submit to Refuge Restrooms
    // ──────────────────────────────────────────────────────────────────────────

    suspend fun submitToRefugeRestrooms(bathroom: Bathroom): Boolean =
        withContext(Dispatchers.IO) {
            val parts   = bathroom.address.split(",").map { it.trim() }
            val payload = JsonObject().apply {
                addProperty("name",       bathroom.name)
                addProperty("street",     parts.getOrElse(0) { bathroom.address })
                addProperty("city",       parts.getOrElse(1) { "" })
                addProperty("state",      parts.getOrElse(2) { "" })
                addProperty("country",    parts.getOrElse(3) { "US" }.ifEmpty { "US" })
                addProperty("accessible", bathroom.isAccessible)
                addProperty("unisex",     bathroom.isGenderNeutral)
                addProperty("latitude",   bathroom.latitude)
                addProperty("longitude",  bathroom.longitude)
                addProperty("directions", bathroom.notes)
            }
            val body    = gson.toJson(payload).toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url("https://www.refugerestrooms.org/api/v1/restrooms")
                .post(body)
                .build()
            try {
                client.newCall(request).execute().code == 201
            } catch (e: Exception) {
                println("Refuge submit error: ${e.message}")
                false
            }
        }
}
