import Foundation
import CoreLocation

struct ToiletDataService {

    // MARK: - Overpass API (OpenStreetMap public toilets)

    static func fetchOverpassToilets(near coord: CLLocationCoordinate2D,
                                     radiusDegrees: Double = 0.045) async -> [Bathroom] {
        let south = coord.latitude  - radiusDegrees
        let north = coord.latitude  + radiusDegrees
        let west  = coord.longitude - radiusDegrees
        let east  = coord.longitude + radiusDegrees
        let bb = "\(south),\(west),\(north),\(east)"

        // Query 1: dedicated toilet facilities (highest priority)
        // Query 2: any venue (gas station, hotel, restaurant, shop, park…) tagged toilets=yes
        let query = """
        [out:json][timeout:30];
        (
          node["amenity"="toilets"](\(bb));
          way["amenity"="toilets"](\(bb));
          node["toilets"="yes"](\(bb));
          way["toilets"="yes"](\(bb));
        );
        out center 100;
        """

        guard let url = URL(string: "https://overpass-api.de/api/interpreter") else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod  = "POST"
        request.httpBody    = ("data=" + (query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""))
            .data(using: .utf8)
        request.timeoutInterval = 35

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response  = try JSONDecoder().decode(OverpassResponse.self, from: data)
            return response.elements.compactMap { overpassToBathroom($0) }
        } catch {
            print("Overpass fetch error: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Refuge Restrooms API (gender-neutral / trans-friendly)

    static func fetchRefugeRestrooms(near coord: CLLocationCoordinate2D) async -> [Bathroom] {
        let urlStr = "https://www.refugerestrooms.org/api/v1/restrooms/by_location.json"
            + "?lat=\(coord.latitude)&lng=\(coord.longitude)&per_page=20&accessible=false"
        guard let url = URL(string: urlStr) else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let entries   = try JSONDecoder().decode([RefugeEntry].self, from: data)
            return entries.compactMap { refugeToBathroom($0) }
        } catch {
            print("Refuge Restrooms fetch error: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Great British Toilet Map (UK — 14,000+ facilities)

    static func fetchGBPTM(near coord: CLLocationCoordinate2D,
                            radiusMeters: Int = 5_000) async -> [Bathroom] {
        guard let url = URL(string: "https://api.toiletmap.org.uk/graphql") else { return [] }

        // GraphQL query — filter out removed loos (removalReason != null)
        let graphql: [String: Any] = [
            "query": """
            query NearbyLoos($lat: Float!, $lng: Float!, $radius: Int!) {
              loosByProximity(lat: $lat, lng: $lng, radius: $radius) {
                id name accessible allGender noPayment openingTimes removalReason
                location { lat lng }
              }
            }
            """,
            "variables": [
                "lat": coord.latitude,
                "lng": coord.longitude,
                "radius": radiusMeters
            ]
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: graphql) else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 20

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response  = try JSONDecoder().decode(GBPTMResponse.self, from: data)
            return (response.data?.loosByProximity ?? [])
                .filter { $0.removalReason == nil }       // only active loos
                .compactMap { gbptmToBathroom($0) }
        } catch {
            print("GBPTM fetch error: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Australia National Public Toilet Map (17,000+ gov-verified)

    static func fetchAustraliaToilets(near coord: CLLocationCoordinate2D,
                                      maxResults: Int = 50) async -> [Bathroom] {
        // Official Australian Government toilet map API
        let urlStr = "https://www.toiletmap.gov.au/Home/GetNearestToilets"
            + "?Latitude=\(coord.latitude)"
            + "&Longitude=\(coord.longitude)"
            + "&MaxNumber=\(maxResults)"
            + "&Radius=5"   // km
        guard let url = URL(string: urlStr) else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        // The gov site requires a browser-like User-Agent
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                         forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let toilets   = try JSONDecoder().decode([AusToilet].self, from: data)
            return toilets.compactMap { ausToiletToBathroom($0) }
        } catch {
            print("Australia toilet fetch error: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Refuge Restrooms: Submit new entry

    /// Submits a new restroom to the Refuge Restrooms community database.
    /// Returns `true` on HTTP 201 Created.
    static func submitToRefugeRestrooms(_ bathroom: Bathroom) async -> Bool {
        guard let url = URL(string: "https://www.refugerestrooms.org/api/v1/restrooms") else {
            return false
        }

        // Split "Street, City, State, Country" out of the combined address field.
        let parts = bathroom.address
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let street  = parts.indices.contains(0) ? parts[0] : bathroom.address
        let city    = parts.indices.contains(1) ? parts[1] : ""
        let state   = parts.indices.contains(2) ? parts[2] : ""
        let country = parts.indices.contains(3) ? parts[3] : ""

        var commentParts: [String] = []
        if !bathroom.hours.isEmpty      { commentParts.append("Hours: \(bathroom.hours)") }
        if bathroom.requiresPurchase    { commentParts.append("Purchase required.") }
        if let code = bathroom.accessCode, !code.isEmpty {
            commentParts.append("Access code: \(code)")
        }

        let body: [String: Any] = [
            "name":           bathroom.name,
            "street":         street,
            "city":           city,
            "state":          state,
            "country":        country.isEmpty ? "US" : country,
            "accessible":     bathroom.isAccessible,
            "unisex":         bathroom.isGenderNeutral,
            "changing_table": false,
            "directions":     bathroom.notes,
            "comment":        commentParts.joined(separator: " "),
            "latitude":       bathroom.latitude,
            "longitude":      bathroom.longitude
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 20

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 201
        } catch {
            print("Refuge Restrooms submit error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Converters

    private static func overpassToBathroom(_ el: OverpassElement) -> Bathroom? {
        let lat: Double
        let lon: Double

        if let elLat = el.lat, let elLon = el.lon {
            lat = elLat; lon = elLon
        } else if let center = el.center {
            lat = center.lat; lon = center.lon
        } else {
            return nil
        }

        let tags = el.tags ?? [:]
        let amenity = tags["amenity"] ?? ""
        let isDedicatedToilet = amenity == "toilets"

        // Map OSM tags → BathroomType + purchase requirement
        let (bathroomType, requiresPurchase): (BathroomType, Bool) = isDedicatedToilet
            ? (.publicFacility, false)
            : osmVenueType(tags: tags)

        // Build a descriptive name: venues get " – Restroom" suffix
        let name: String
        if isDedicatedToilet {
            name = tags["name"] ?? tags["description"] ?? "Public Toilet"
        } else {
            if let venueName = tags["name"], !venueName.trimmingCharacters(in: .whitespaces).isEmpty {
                name = "\(venueName) – Restroom"
            } else {
                name = "\(bathroomType.displayName) Restroom"
            }
        }

        let fee: FeeType = {
            switch tags["fee"] {
            case "no", "free": return .free
            case "yes":        return .paid
            default:           return isDedicatedToilet ? .unknown : .free
            }
        }()

        let accessible    = tags["wheelchair"] == "yes" || tags["wheelchair"] == "designated"
        let genderNeutral = tags["unisex"] == "yes"
        let hours         = tags["opening_hours"] ?? ""
        let access        = tags["access"] ?? ""
        var notes         = access.isEmpty ? "" : "Access: \(access)"
        if requiresPurchase {
            notes = notes.isEmpty ? "May require a purchase." : notes + " May require a purchase."
        }

        // Deterministic UUID: prefix "4F534D30" = "OSM0" in ASCII hex
        let idHex   = String(format: "%012X", el.id)
        let uuidStr = "4F534D30-0000-4000-8000-\(idHex)"
        let id      = UUID(uuidString: uuidStr) ?? UUID()

        return Bathroom(
            id: id,
            name: name,
            address: "",
            latitude: lat,
            longitude: lon,
            type: bathroomType,
            fee: fee,
            isAccessible: accessible,
            isGenderNeutral: genderNeutral,
            requiresPurchase: requiresPurchase,
            accessCode: nil,
            notes: notes,
            hours: hours,
            isVerified: true,
            dateAdded: Date(),
            isFavorite: false,
            reviews: []
        )
    }

    /// Maps OSM tags to the best-fit BathroomType and whether a purchase is likely required.
    private static func osmVenueType(tags: [String: String]) -> (BathroomType, Bool) {
        let amenity = tags["amenity"] ?? ""
        let tourism  = tags["tourism"] ?? ""
        let shop     = tags["shop"] ?? ""
        let leisure  = tags["leisure"] ?? ""

        switch amenity {
        // Gas / fuel stations
        case "fuel":
            return (.gasStation, false)
        // Food & drink — toilet access often requires purchase
        case "restaurant", "fast_food", "cafe", "bar",
             "pub", "food_court", "biergarten", "ice_cream":
            return (.restaurant, true)
        // Public-service buildings — free access
        case "hospital", "clinic", "doctors", "pharmacy", "dentist",
             "library", "community_centre", "arts_centre",
             "theatre", "cinema", "place_of_worship",
             "ferry_terminal", "bus_station", "airport":
            return (.publicFacility, false)
        // Shopping complexes
        case "shopping_mall":
            return (.store, false)
        case "supermarket", "convenience":
            return (.store, true)
        default:
            break
        }
        // Accommodation
        switch tourism {
        case "hotel", "motel", "hostel", "guest_house",
             "apartment", "chalet", "camp_site":
            return (.hotel, false)
        default:
            break
        }
        // Retail shops
        if !shop.isEmpty { return (.store, true) }
        // Outdoor / leisure
        switch leisure {
        case "park", "recreation_ground", "garden", "nature_reserve",
             "dog_park", "playground":
            return (.park, false)
        case "sports_centre", "stadium", "fitness_centre",
             "swimming_pool", "golf_course":
            return (.publicFacility, false)
        default:
            break
        }
        return (.other, false)
    }

    private static func refugeToBathroom(_ entry: RefugeEntry) -> Bathroom? {
        guard entry.latitude != 0, entry.longitude != 0 else { return nil }

        // Deterministic UUID: prefix "52465547" = "RFUG" in ASCII hex
        let idHex   = String(format: "%012X", abs(entry.id))
        let uuidStr = "52465547-0000-4000-8000-\(idHex)"
        let id = UUID(uuidString: uuidStr) ?? UUID()

        let name    = entry.name.trimmingCharacters(in: .whitespaces).isEmpty
                      ? "Refuge Restroom"
                      : entry.name
        let address = [entry.street, entry.city, entry.state, entry.country]
            .compactMap { s -> String? in
                guard let s, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                return s
            }
            .joined(separator: ", ")

        return Bathroom(
            id: id,
            name: name,
            address: address,
            latitude: entry.latitude,
            longitude: entry.longitude,
            type: .publicFacility,
            fee: .free,
            isAccessible: entry.accessible,
            isGenderNeutral: true,
            requiresPurchase: false,
            accessCode: nil,
            notes: entry.directions ?? "",
            hours: "",
            isVerified: true,
            dateAdded: Date(),
            isFavorite: false,
            reviews: []
        )
    }

    private static func gbptmToBathroom(_ loo: GBPTMLoo) -> Bathroom? {
        guard let loc = loo.location else { return nil }

        // Deterministic UUID: prefix "47425054" = "GBPT" in ASCII hex
        // GBPTM IDs are hex strings — take first 12 hex chars
        let hexChars   = loo.id.filter { $0.isHexDigit }
        let hexPart    = String(hexChars.prefix(12)).padding(toLength: 12, withPad: "0", startingAt: 0).uppercased()
        let id         = UUID(uuidString: "47425054-0000-4000-8000-\(hexPart)") ?? UUID()
        let name       = loo.name?.trimmingCharacters(in: .whitespaces).isEmpty == false
                         ? loo.name! : "Public Toilet"
        let fee: FeeType = loo.noPayment == true ? .free : loo.noPayment == false ? .paid : .unknown

        return Bathroom(
            id: id,
            name: name,
            address: "",
            latitude: loc.lat,
            longitude: loc.lng,
            type: .publicFacility,
            fee: fee,
            isAccessible: loo.accessible ?? false,
            isGenderNeutral: loo.allGender ?? false,
            requiresPurchase: false,
            accessCode: nil,
            notes: "",
            hours: loo.openingTimes ?? "",
            isVerified: true,
            dateAdded: Date(),
            isFavorite: false,
            reviews: []
        )
    }

    private static func ausToiletToBathroom(_ t: AusToilet) -> Bathroom? {
        guard let lat = t.Latitude, let lon = t.Longitude,
              lat != 0, lon != 0 else { return nil }

        // Deterministic UUID: prefix "41555354" = "AUST" in ASCII hex
        let idHex   = String(format: "%012X", abs(t.ToiletID ?? 0))
        let id      = UUID(uuidString: "41555354-0000-4000-8000-\(idHex)") ?? UUID()
        let name    = t.Name?.isEmpty == false ? t.Name! : "Public Toilet"
        let parts   = [t.Address1, t.Town, t.State, t.Postcode]
            .compactMap { s -> String? in
                guard let s = s, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                return s
            }
        let address = parts.joined(separator: ", ")

        let accessible = (t.AccessibleMale == "Yes" ||
                          t.AccessibleFemale == "Yes" ||
                          t.AccessibleUnisex == "Yes")
        let genderNeutral = t.Unisex == "Yes"
        let fee: FeeType  = t.PayToilet == "Yes" ? .paid : .free

        var notes: [String] = []
        if t.BabyChange == "Yes" { notes.append("Baby change available.") }
        if let n = t.Notes, !n.isEmpty { notes.append(n) }

        return Bathroom(
            id: id,
            name: name,
            address: address,
            latitude: lat,
            longitude: lon,
            type: .publicFacility,
            fee: fee,
            isAccessible: accessible,
            isGenderNeutral: genderNeutral,
            requiresPurchase: false,
            accessCode: nil,
            notes: notes.joined(separator: " "),
            hours: t.OpeningHours ?? "",
            isVerified: true,
            dateAdded: Date(),
            isFavorite: false,
            reviews: []
        )
    }
}

// MARK: - JSON models

private struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

private struct OverpassElement: Decodable {
    let id:     Int
    let lat:    Double?
    let lon:    Double?
    let center: OverpassCenter?
    let tags:   [String: String]?
}

private struct OverpassCenter: Decodable {
    let lat: Double
    let lon: Double
}

// MARK: - Great British Toilet Map JSON models

private struct GBPTMResponse: Decodable {
    let data: GBPTMData?
}
private struct GBPTMData: Decodable {
    let loosByProximity: [GBPTMLoo]?
}
private struct GBPTMLoo: Decodable {
    let id:            String
    let name:          String?
    let location:      GBPTMLocation?
    let accessible:    Bool?
    let allGender:     Bool?
    let noPayment:     Bool?
    let openingTimes:  String?
    let removalReason: String?
}
private struct GBPTMLocation: Decodable {
    let lat: Double
    let lng: Double
}

// MARK: - Australia National Toilet Map JSON model

private struct AusToilet: Decodable {
    let ToiletID:         Int?
    let Name:             String?
    let Address1:         String?
    let Town:             String?
    let State:            String?
    let Postcode:         String?
    let Latitude:         Double?
    let Longitude:        Double?
    let AccessibleMale:   String?
    let AccessibleFemale: String?
    let AccessibleUnisex: String?
    let Unisex:           String?
    let PayToilet:        String?
    let BabyChange:       String?
    let Notes:            String?
    let OpeningHours:     String?
}

// MARK: - Refuge Restrooms JSON model

private struct RefugeEntry: Decodable {
    let id:         Int
    let name:       String
    let street:     String?
    let city:       String?
    let state:      String?
    let country:    String?
    let latitude:   Double
    let longitude:  Double
    let accessible: Bool
    let directions: String?
}
