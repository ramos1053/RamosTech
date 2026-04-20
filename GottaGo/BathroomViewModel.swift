import Foundation
import CoreLocation
import MapKit
import Combine
import UIKit

@MainActor
class BathroomViewModel: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var bathrooms: [Bathroom] = []
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var selectedBathroom: Bathroom?
    @Published var showAddBathroom = false
    @Published var filterFreeOnly = false
    @Published var filterAccessibleOnly = false
    @Published var filterGenderNeutral = false
    @Published var searchText = ""
    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var selectedTab: Int = 0

    // Favorites ordering (persisted separately so we don't re-sort main array)
    @Published var favoritesOrder: [UUID] = []

    // Route state
    @Published var currentRoute: MKRoute?
    @Published var routeDestination: Bathroom?
    @Published var routeETA: TimeInterval = 0
    @Published var routeCalories: Int = 0
    @Published var routeDistance: Double = 0
    @Published var isCalculatingRoute = false

    // Map style
    @Published var mapStyleOption: MapStyleOption = .standard

    // External (API) bathrooms
    @Published var externalBathrooms: [Bathroom] = []
    @Published var isFetchingExternal = false
    private var lastFetchLocation: CLLocationCoordinate2D?

    // iCloud sync
    @Published var iCloudAvailable = false

    private let locationManager = CLLocationManager()
    private let bathroomsKey  = "gottago_bathrooms_v1"
    private let favOrderKey   = "gottago_favorites_order"
    private let iCloudStore   = NSUbiquitousKeyValueStore.default

    // MARK: - Init
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        loadBathrooms()
        setupICloudSync()
    }

    // MARK: - iCloud Key-Value Store

    private func setupICloudSync() {
        // Trigger an initial sync so the store has the latest data from iCloud
        iCloudStore.synchronize()
        iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil

        // React to iCloud pushing changes down (e.g. restored to another device)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )
        // Re-sync whenever the app comes back to the foreground
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc nonisolated private func appDidBecomeActive() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.iCloudStore.synchronize()
            self.iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        }
    }

    @objc nonisolated private func iCloudStoreDidChange(_ notification: Notification) {
        guard let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int,
              reason == NSUbiquitousKeyValueStoreServerChange ||
              reason == NSUbiquitousKeyValueStoreInitialSyncChange
        else { return }

        Task { @MainActor [weak self] in
            self?.mergeFromICloud()
        }
    }

    /// Called after a fresh install (UserDefaults empty) or when iCloud pushes new data.
    /// Merges cloud bathrooms into local, preferring local on UUID collision.
    private func mergeFromICloud() {
        guard let cloudData = iCloudStore.data(forKey: bathroomsKey),
              let cloudBathrooms = try? JSONDecoder().decode([Bathroom].self, from: cloudData),
              !cloudBathrooms.isEmpty
        else { return }

        let localIds = Set(bathrooms.map { $0.id })
        let newEntries = cloudBathrooms.filter { !localIds.contains($0.id) }

        guard !newEntries.isEmpty else { return }
        bathrooms.append(contentsOf: newEntries)

        // Also merge favorites order if local has none yet
        if favoritesOrder.isEmpty,
           let favData = iCloudStore.data(forKey: favOrderKey),
           let cloudOrder = try? JSONDecoder().decode([UUID].self, from: favData) {
            favoritesOrder = cloudOrder
        }
        // Persist the merged result locally
        saveBathrooms()
    }

    /// Writes current data to iCloud KV store (best-effort, silently skips if over quota).
    private func syncToICloud() {
        guard iCloudAvailable,
              let bathroomsData = try? JSONEncoder().encode(bathrooms),
              let favData       = try? JSONEncoder().encode(favoritesOrder)
        else { return }

        // NSUbiquitousKeyValueStore hard limit is 1 MB total per app.
        // Stay well under to avoid quota errors.
        guard bathroomsData.count + favData.count < 900_000 else {
            print("iCloud KV: data too large to sync (\(bathroomsData.count + favData.count) bytes)")
            return
        }

        iCloudStore.set(bathroomsData, forKey: bathroomsKey)
        iCloudStore.set(favData,       forKey: favOrderKey)
        iCloudStore.synchronize()
    }

    // MARK: - Location
    func requestLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    // MARK: - All Bathrooms (local + external, local wins on duplicate IDs)
    var allBathrooms: [Bathroom] {
        let localIds = Set(bathrooms.map { $0.id })
        let uniqueExternal = externalBathrooms.filter { !localIds.contains($0.id) }
        return bathrooms + uniqueExternal
    }

    // MARK: - Filtering
    var filteredBathrooms: [Bathroom] {
        var result = allBathrooms
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.address.localizedCaseInsensitiveContains(searchText) ||
                $0.notes.localizedCaseInsensitiveContains(searchText)
            }
        }
        if filterFreeOnly       { result = result.filter { $0.fee == .free } }
        if filterAccessibleOnly { result = result.filter { $0.isAccessible } }
        if filterGenderNeutral  { result = result.filter { $0.isGenderNeutral } }
        return result
    }

    var sortedByDistance: [Bathroom] {
        guard let userLoc = userLocation else { return filteredBathrooms }
        let user = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        return filteredBathrooms.sorted {
            let a = CLLocation(latitude: $0.latitude, longitude: $0.longitude)
            let b = CLLocation(latitude: $1.latitude, longitude: $1.longitude)
            return a.distance(from: user) < b.distance(from: user)
        }
    }

    // Favorites in user-defined order
    var favorites: [Bathroom] {
        let favMap = Dictionary(uniqueKeysWithValues:
            bathrooms.filter { $0.isFavorite }.map { ($0.id, $0) }
        )
        var ordered = favoritesOrder.compactMap { favMap[$0] }
        // Append any new favorites not yet in the order list
        let knownIds = Set(favoritesOrder)
        for b in bathrooms where b.isFavorite && !knownIds.contains(b.id) {
            ordered.append(b)
        }
        return ordered
    }

    func distance(to bathroom: Bathroom) -> String? {
        guard let userLoc = userLocation else { return nil }
        let user = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let dest = CLLocation(latitude: bathroom.latitude, longitude: bathroom.longitude)
        let meters = dest.distance(from: user)
        if meters < 1000 { return "\(Int(meters))m away" }
        return String(format: "%.1fkm away", meters / 1000)
    }

    // MARK: - Favorites
    func toggleFavorite(_ bathroom: Bathroom) {
        guard let index = bathrooms.firstIndex(where: { $0.id == bathroom.id }) else { return }
        let wasFav = bathrooms[index].isFavorite
        bathrooms[index].isFavorite.toggle()
        if !wasFav {
            // Newly favorited — append to order
            if !favoritesOrder.contains(bathroom.id) {
                favoritesOrder.append(bathroom.id)
            }
        } else {
            // Un-favorited — remove from order
            favoritesOrder.removeAll { $0 == bathroom.id }
        }
        saveBathrooms()
    }

    func isFavorite(_ bathroom: Bathroom) -> Bool {
        bathrooms.first(where: { $0.id == bathroom.id })?.isFavorite ?? false
    }

    /// True if the bathroom lives in local storage (user-added or sample data).
    func isLocalBathroom(_ bathroom: Bathroom) -> Bool {
        bathrooms.contains(where: { $0.id == bathroom.id })
    }

    func moveFavorites(from: IndexSet, to: Int) {
        // Build a current ordered list of IDs then move
        var ids = favorites.map { $0.id }
        ids.move(fromOffsets: from, toOffset: to)
        favoritesOrder = ids
        saveFavoritesOrder()
    }

    // MARK: - Route
    func calculateRoute(to bathroom: Bathroom) async {
        guard let userLoc = userLocation else { return }
        isCalculatingRoute = true
        defer { isCalculatingRoute = false }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLoc))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: bathroom.coordinate))
        request.transportType = .walking

        do {
            let response = try await MKDirections(request: request).calculate()
            if let route = response.routes.first {
                currentRoute = route
                routeETA = route.expectedTravelTime
                routeDistance = route.distance
                routeCalories = max(1, Int(route.distance / 1000.0 * 60))
                routeDestination = bathroom
            }
        } catch {
            print("Route error: \(error.localizedDescription)")
        }
    }

    func clearRoute() {
        currentRoute = nil
        routeDestination = nil
        routeETA = 0
        routeCalories = 0
        routeDistance = 0
    }

    func startRouteFromFavorites(to bathroom: Bathroom) {
        selectedTab = 0
        Task { await calculateRoute(to: bathroom) }
    }

    // MARK: - External Data Fetch
    func fetchExternalBathrooms(near coord: CLLocationCoordinate2D) async {
        // Skip if we recently fetched from nearly the same spot (within ~1 km)
        if let last = lastFetchLocation {
            let lastLoc    = CLLocation(latitude: last.latitude,  longitude: last.longitude)
            let currentLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if currentLoc.distance(from: lastLoc) < 1_000 { return }
        }
        guard !isFetchingExternal else { return }

        isFetchingExternal  = true
        lastFetchLocation   = coord

        // Fire all four sources simultaneously
        async let overpassFetch  = ToiletDataService.fetchOverpassToilets(near: coord)
        async let refugeFetch    = ToiletDataService.fetchRefugeRestrooms(near: coord)
        async let gbptmFetch     = ToiletDataService.fetchGBPTM(near: coord)
        async let australiaFetch = ToiletDataService.fetchAustraliaToilets(near: coord)

        let (overpassResults, refugeResults, gbptmResults, australiaResults) =
            await (overpassFetch, refugeFetch, gbptmFetch, australiaFetch)

        // Deduplicate by proximity: keep UUID-stable entries, skip co-located duplicates
        var merged = overpassResults
        func key(_ b: Bathroom) -> String {
            "\(Int(b.latitude * 10_000)),\(Int(b.longitude * 10_000))"
        }
        var seenKeys = Set(merged.map { key($0) })

        for batch in [refugeResults, gbptmResults, australiaResults] {
            for entry in batch {
                let k = key(entry)
                if !seenKeys.contains(k) {
                    seenKeys.insert(k)
                    merged.append(entry)
                }
            }
        }

        externalBathrooms  = merged
        isFetchingExternal = false
    }

    // MARK: - Data Mutations
    func addBathroom(_ bathroom: Bathroom) {
        bathrooms.append(bathroom)
        saveBathrooms()
    }

    func addReview(_ review: Review, to bathroomId: UUID) {
        guard let index = bathrooms.firstIndex(where: { $0.id == bathroomId }) else { return }
        bathrooms[index].reviews.append(review)
        saveBathrooms()
    }

    func deleteBathroom(_ bathroom: Bathroom) {
        bathrooms.removeAll { $0.id == bathroom.id }
        favoritesOrder.removeAll { $0 == bathroom.id }
        saveBathrooms()
    }

    // MARK: - Persistence
    private func saveBathrooms() {
        if let encoded = try? JSONEncoder().encode(bathrooms) {
            UserDefaults.standard.set(encoded, forKey: bathroomsKey)
        }
        saveFavoritesOrder()
        syncToICloud()
    }

    private func saveFavoritesOrder() {
        if let encoded = try? JSONEncoder().encode(favoritesOrder) {
            UserDefaults.standard.set(encoded, forKey: favOrderKey)
        }
    }

    private func loadBathrooms() {
        // 1. Try UserDefaults (normal path)
        if let data = UserDefaults.standard.data(forKey: bathroomsKey),
           let decoded = try? JSONDecoder().decode([Bathroom].self, from: data) {
            bathrooms = decoded
        } else {
            // 2. UserDefaults empty → try iCloud restore (fresh install / wiped phone)
            if let cloudData = iCloudStore.data(forKey: bathroomsKey),
               let cloudBathrooms = try? JSONDecoder().decode([Bathroom].self, from: cloudData),
               !cloudBathrooms.isEmpty {
                bathrooms = cloudBathrooms
                print("iCloud: restored \(cloudBathrooms.count) bathrooms from iCloud KV store")
            } else {
                bathrooms = Bathroom.sampleData
            }
        }

        // Load favorites order — same two-step fallback
        if let data = UserDefaults.standard.data(forKey: favOrderKey),
           let order = try? JSONDecoder().decode([UUID].self, from: data) {
            favoritesOrder = order
        } else if let cloudFavData = iCloudStore.data(forKey: favOrderKey),
                  let cloudOrder = try? JSONDecoder().decode([UUID].self, from: cloudFavData) {
            favoritesOrder = cloudOrder
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension BathroomViewModel: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.userLocation = location.coordinate
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.locationAuthorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
