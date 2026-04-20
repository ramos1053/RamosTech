//
//  PreferencesManager.swift
//  Nimbus-Swift
//

import Foundation
import Combine

class PreferencesManager: ObservableObject {
    @Published var preferences: AppPreferences

    private let userDefaults = UserDefaults.standard
    private let prefsKey = "NimbusPreferences"

    init() {
        // Load preferences from UserDefaults
        if let data = userDefaults.data(forKey: prefsKey),
           let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            self.preferences = decoded
        } else {
            self.preferences = .default
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            userDefaults.set(encoded, forKey: prefsKey)
        }
    }
}
