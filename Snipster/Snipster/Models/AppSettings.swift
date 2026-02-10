//
//  AppSettings.swift
//  Snipster
//
//  Created by Alan Ramos on 12/17/25.
//

import SwiftUI
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("previewLines") var previewLines: Int = 2

    private init() {}
}
