import Foundation
import CoreLocation
import MapKit
import SwiftUI

// MARK: - Map Style

enum MapStyleOption: String, CaseIterable {
    case standard  = "Standard"
    case satellite = "Satellite"
    case hybrid    = "Hybrid"

    var mapStyle: MapStyle {
        switch self {
        case .standard:  return .standard(elevation: .realistic)
        case .satellite: return .imagery
        case .hybrid:    return .hybrid
        }
    }

    var icon: String {
        switch self {
        case .standard:  return "map"
        case .satellite: return "globe.americas.fill"
        case .hybrid:    return "square.3.layers.3d"
        }
    }
}

// MARK: - Enums

enum BathroomType: String, CaseIterable, Codable {
    case publicFacility = "public"
    case restaurant = "restaurant"
    case hotel = "hotel"
    case store = "store"
    case gasStation = "gasStation"
    case park = "park"
    case other = "other"

    var displayName: String {
        switch self {
        case .publicFacility: return "Public"
        case .restaurant:     return "Restaurant"
        case .hotel:          return "Hotel"
        case .store:          return "Store"
        case .gasStation:     return "Gas Station"
        case .park:           return "Park"
        case .other:          return "Other"
        }
    }

    var icon: String {
        switch self {
        case .publicFacility: return "building.columns.fill"
        case .restaurant:     return "fork.knife"
        case .hotel:          return "bed.double.fill"
        case .store:          return "cart.fill"
        case .gasStation:     return "fuelpump.fill"
        case .park:           return "leaf.fill"
        case .other:          return "questionmark.circle.fill"
        }
    }
}

enum FeeType: String, CaseIterable, Codable {
    case free    = "free"
    case paid    = "paid"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .free:    return "Free"
        case .paid:    return "Paid"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Review

struct Review: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var authorName: String
    var rating: Double      // 1–5 overall
    var cleanliness: Double // 1–5
    var comment: String
    var date: Date

    static func == (lhs: Review, rhs: Review) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Bathroom

struct Bathroom: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var type: BathroomType
    var fee: FeeType
    var isAccessible: Bool
    var isGenderNeutral: Bool
    var requiresPurchase: Bool
    var accessCode: String?
    var notes: String
    var hours: String
    var isVerified: Bool
    var dateAdded: Date
    var isFavorite: Bool = false
    var reviews: [Review]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return reviews.map(\.rating).reduce(0, +) / Double(reviews.count)
    }

    var averageCleanliness: Double {
        guard !reviews.isEmpty else { return 0 }
        return reviews.map(\.cleanliness).reduce(0, +) / Double(reviews.count)
    }

    static func == (lhs: Bathroom, rhs: Bathroom) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // MARK: Sample Data
    static let sampleData: [Bathroom] = [
        Bathroom(
            name: "Bryant Park Restrooms",
            address: "42nd St & 6th Ave, New York, NY",
            latitude: 40.7536,
            longitude: -73.9832,
            type: .publicFacility,
            fee: .free,
            isAccessible: true,
            isGenderNeutral: false,
            requiresPurchase: false,
            accessCode: nil,
            notes: "Well maintained public restrooms inside Bryant Park. Attendant on duty most hours.",
            hours: "7:00 AM – 11:00 PM",
            isVerified: true,
            dateAdded: Date(),
            reviews: [
                Review(authorName: "Alex", rating: 4.0, cleanliness: 4.5,
                       comment: "Very clean and well maintained!", date: Date()),
                Review(authorName: "Jordan", rating: 3.5, cleanliness: 3.0,
                       comment: "Gets crowded during lunch hour but still fine.", date: Date())
            ]
        ),
        Bathroom(
            name: "Grand Central Terminal",
            address: "89 E 42nd St, New York, NY",
            latitude: 40.7527,
            longitude: -73.9772,
            type: .publicFacility,
            fee: .free,
            isAccessible: true,
            isGenderNeutral: false,
            requiresPurchase: false,
            accessCode: nil,
            notes: "Located on the lower level near the food court. Large and clean.",
            hours: "5:30 AM – 2:00 AM",
            isVerified: true,
            dateAdded: Date(),
            reviews: [
                Review(authorName: "Sam", rating: 4.5, cleanliness: 4.0,
                       comment: "Clean and spacious. Easy to find on the lower level.", date: Date())
            ]
        ),
        Bathroom(
            name: "Starbucks – Times Square",
            address: "1585 Broadway, New York, NY",
            latitude: 40.7589,
            longitude: -73.9851,
            type: .restaurant,
            fee: .free,
            isAccessible: true,
            isGenderNeutral: true,
            requiresPurchase: true,
            accessCode: "1234",
            notes: "Purchase required. Ask staff for door code. Gender-neutral single-stall.",
            hours: "5:00 AM – 11:00 PM",
            isVerified: false,
            dateAdded: Date(),
            reviews: [
                Review(authorName: "Morgan", rating: 3.0, cleanliness: 3.5,
                       comment: "Small but decent. Code changes occasionally.", date: Date())
            ]
        )
    ]
}
