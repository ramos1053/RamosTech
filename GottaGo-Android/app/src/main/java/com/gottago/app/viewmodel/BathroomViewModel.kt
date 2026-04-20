package com.gottago.app.viewmodel

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.maps.model.LatLng
import com.gottago.app.data.BathroomRepository
import com.gottago.app.model.Bathroom
import com.gottago.app.model.Review
import com.gottago.app.service.ToiletDataService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlin.math.abs

class BathroomViewModel(context: Context) {

    private val repo       = BathroomRepository(context)
    private val scope      = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val fusedLocation = LocationServices.getFusedLocationProviderClient(context)

    // ──────────────────────────────────────────────────────────────────────────
    // State
    // ──────────────────────────────────────────────────────────────────────────

    private val _bathrooms        = MutableStateFlow<List<Bathroom>>(emptyList())
    val bathrooms: StateFlow<List<Bathroom>> = _bathrooms.asStateFlow()

    private val _externalBathrooms = MutableStateFlow<List<Bathroom>>(emptyList())
    val externalBathrooms: StateFlow<List<Bathroom>> = _externalBathrooms.asStateFlow()

    private val _userLocation     = MutableStateFlow<LatLng?>(null)
    val userLocation: StateFlow<LatLng?> = _userLocation.asStateFlow()

    private val _isFetchingExternal = MutableStateFlow(false)
    val isFetchingExternal: StateFlow<Boolean> = _isFetchingExternal.asStateFlow()

    private val _favoritesOrder   = MutableStateFlow<List<String>>(emptyList())
    val favoritesOrder: StateFlow<List<String>> = _favoritesOrder.asStateFlow()

    // Filters
    private val _filterFreeOnly       = MutableStateFlow(false)
    val filterFreeOnly: StateFlow<Boolean> = _filterFreeOnly.asStateFlow()

    private val _filterAccessibleOnly = MutableStateFlow(false)
    val filterAccessibleOnly: StateFlow<Boolean> = _filterAccessibleOnly.asStateFlow()

    private val _filterGenderNeutral  = MutableStateFlow(false)
    val filterGenderNeutral: StateFlow<Boolean> = _filterGenderNeutral.asStateFlow()

    private val _searchText           = MutableStateFlow("")
    val searchText: StateFlow<String> = _searchText.asStateFlow()

    private val _selectedTab          = MutableStateFlow(0)
    val selectedTab: StateFlow<Int> = _selectedTab.asStateFlow()

    private val _mapTypeIndex         = MutableStateFlow(0) // 0=normal,1=satellite,2=hybrid
    val mapTypeIndex: StateFlow<Int> = _mapTypeIndex.asStateFlow()

    private var lastFetchLocation: LatLng? = null

    // ──────────────────────────────────────────────────────────────────────────
    // Init
    // ──────────────────────────────────────────────────────────────────────────

    init {
        _bathrooms.value      = repo.loadBathrooms().toMutableList()
        _favoritesOrder.value = repo.loadFavoritesOrder()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Combined list
    // ──────────────────────────────────────────────────────────────────────────

    val allBathrooms: List<Bathroom>
        get() {
            val localIds = _bathrooms.value.map { it.id }.toSet()
            return _bathrooms.value + _externalBathrooms.value.filter { it.id !in localIds }
        }

    val filteredBathrooms: List<Bathroom>
        get() {
            var list = allBathrooms
            val q = _searchText.value.trim().lowercase()
            if (q.isNotEmpty()) {
                list = list.filter {
                    it.name.lowercase().contains(q) ||
                    it.address.lowercase().contains(q) ||
                    it.notes.lowercase().contains(q)
                }
            }
            if (_filterFreeOnly.value)       list = list.filter { it.fee.name == "FREE" }
            if (_filterAccessibleOnly.value) list = list.filter { it.isAccessible }
            if (_filterGenderNeutral.value)  list = list.filter { it.isGenderNeutral }
            return list
        }

    val sortedByDistance: List<Bathroom>
        get() {
            val loc = _userLocation.value ?: return filteredBathrooms
            return filteredBathrooms.sortedBy { distanceMeters(loc, it.latitude, it.longitude) }
        }

    val favorites: List<Bathroom>
        get() {
            val favMap = _bathrooms.value.filter { it.isFavorite }.associateBy { it.id }
            val ordered = _favoritesOrder.value.mapNotNull { favMap[it] }.toMutableList()
            val knownIds = _favoritesOrder.value.toSet()
            _bathrooms.value.filter { it.isFavorite && it.id !in knownIds }.forEach { ordered.add(it) }
            return ordered
        }

    fun distanceText(bathroom: Bathroom): String? {
        val loc = _userLocation.value ?: return null
        val meters = distanceMeters(loc, bathroom.latitude, bathroom.longitude)
        return if (meters < 1000) "${meters.toInt()} m away"
        else "%.1f km away".format(meters / 1000.0)
    }

    private fun distanceMeters(from: LatLng, toLat: Double, toLng: Double): Float {
        val res = FloatArray(1)
        Location.distanceBetween(from.latitude, from.longitude, toLat, toLng, res)
        return res[0]
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Location
    // ──────────────────────────────────────────────────────────────────────────

    @SuppressLint("MissingPermission")
    fun startLocationUpdates() {
        val req = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10_000L)
            .setMinUpdateIntervalMillis(5_000L)
            .build()
        fusedLocation.requestLocationUpdates(req, object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val loc = result.lastLocation ?: return
                _userLocation.value = LatLng(loc.latitude, loc.longitude)
                fetchExternalBathrooms(loc.latitude, loc.longitude)
            }
        }, android.os.Looper.getMainLooper())
    }

    // ──────────────────────────────────────────────────────────────────────────
    // External fetch (all 4 APIs, parallel)
    // ──────────────────────────────────────────────────────────────────────────

    fun fetchExternalBathrooms(lat: Double, lng: Double) {
        val current = LatLng(lat, lng)
        lastFetchLocation?.let { last ->
            val res = FloatArray(1)
            Location.distanceBetween(last.latitude, last.longitude, lat, lng, res)
            if (res[0] < 1_000f) return  // same area
        }
        if (_isFetchingExternal.value) return

        _isFetchingExternal.value = true
        lastFetchLocation = current

        scope.launch {
            val overpassDeferred  = async(Dispatchers.IO) { ToiletDataService.fetchOverpassToilets(lat, lng) }
            val refugeDeferred    = async(Dispatchers.IO) { ToiletDataService.fetchRefugeRestrooms(lat, lng) }
            val gbptmDeferred     = async(Dispatchers.IO) { ToiletDataService.fetchGBPTM(lat, lng) }
            val australiaDeferred = async(Dispatchers.IO) { ToiletDataService.fetchAustraliaToilets(lat, lng) }

            val overpass  = overpassDeferred.await()
            val refuge    = refugeDeferred.await()
            val gbptm     = gbptmDeferred.await()
            val australia = australiaDeferred.await()

            fun proximityKey(b: Bathroom) = "${(b.latitude * 10_000).toInt()},${(b.longitude * 10_000).toInt()}"

            val merged = overpass.toMutableList()
            val seen   = merged.map { proximityKey(it) }.toMutableSet()
            for (batch in listOf(refuge, gbptm, australia)) {
                for (entry in batch) {
                    val k = proximityKey(entry)
                    if (k !in seen) { seen.add(k); merged.add(entry) }
                }
            }

            _externalBathrooms.value = merged
            _isFetchingExternal.value = false
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // CRUD
    // ──────────────────────────────────────────────────────────────────────────

    fun addBathroom(bathroom: Bathroom) {
        _bathrooms.value = _bathrooms.value + bathroom
        save()
    }

    fun deleteBathroom(bathroom: Bathroom) {
        _bathrooms.value = _bathrooms.value.filter { it.id != bathroom.id }
        _favoritesOrder.value = _favoritesOrder.value.filter { it != bathroom.id }
        save()
    }

    fun toggleFavorite(bathroom: Bathroom) {
        val list = _bathrooms.value.toMutableList()
        val idx  = list.indexOfFirst { it.id == bathroom.id }
        if (idx < 0) {
            // External bathroom — copy to local first
            val copy = bathroom.copy(isFavorite = true)
            list.add(copy)
            _favoritesOrder.value = _favoritesOrder.value + copy.id
        } else {
            val wasFav = list[idx].isFavorite
            list[idx] = list[idx].copy(isFavorite = !wasFav)
            _favoritesOrder.value = if (wasFav)
                _favoritesOrder.value.filter { it != bathroom.id }
            else if (bathroom.id !in _favoritesOrder.value)
                _favoritesOrder.value + bathroom.id
            else _favoritesOrder.value
        }
        _bathrooms.value = list
        save()
    }

    fun isFavorite(bathroom: Bathroom): Boolean =
        _bathrooms.value.firstOrNull { it.id == bathroom.id }?.isFavorite ?: false

    fun isLocalBathroom(bathroom: Bathroom): Boolean =
        _bathrooms.value.any { it.id == bathroom.id }

    fun moveFavorites(fromIndex: Int, toIndex: Int) {
        val ids = favorites.map { it.id }.toMutableList()
        val item = ids.removeAt(fromIndex)
        ids.add(toIndex, item)
        _favoritesOrder.value = ids
        repo.saveFavoritesOrder(ids)
    }

    fun addReview(bathroomId: String, review: Review) {
        val list = _bathrooms.value.toMutableList()
        val updated = repo.addReview(list, bathroomId, review)
        _bathrooms.value = updated
        save()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Filter setters
    // ──────────────────────────────────────────────────────────────────────────

    fun setFilterFreeOnly(v: Boolean)       { _filterFreeOnly.value = v }
    fun setFilterAccessibleOnly(v: Boolean) { _filterAccessibleOnly.value = v }
    fun setFilterGenderNeutral(v: Boolean)  { _filterGenderNeutral.value = v }
    fun setSearchText(v: String)            { _searchText.value = v }
    fun setSelectedTab(v: Int)              { _selectedTab.value = v }
    fun setMapTypeIndex(v: Int)             { _mapTypeIndex.value = v }

    // ──────────────────────────────────────────────────────────────────────────
    // Persistence
    // ──────────────────────────────────────────────────────────────────────────

    private fun save() {
        repo.saveBathrooms(_bathrooms.value)
        repo.saveFavoritesOrder(_favoritesOrder.value)
    }
}
