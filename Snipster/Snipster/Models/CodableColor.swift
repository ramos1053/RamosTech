//
//  CodableColor.swift
//  Snipster
//
//  Created by Alan Ramos on 12/17/25.
//

import SwiftUI

extension Color: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let red = try container.decode(Double.self, forKey: .red)
        let green = try container.decode(Double.self, forKey: .green)
        let blue = try container.decode(Double.self, forKey: .blue)
        let opacity = try container.decode(Double.self, forKey: .opacity)

        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Extract RGB components from Color using NSColor on macOS
        #if canImport(AppKit)
        guard let nsColor = NSColor(self).usingColorSpace(.deviceRGB) else {
            throw EncodingError.invalidValue(self, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Unable to convert Color to RGB color space"
            ))
        }

        try container.encode(Double(nsColor.redComponent), forKey: .red)
        try container.encode(Double(nsColor.greenComponent), forKey: .green)
        try container.encode(Double(nsColor.blueComponent), forKey: .blue)
        try container.encode(Double(nsColor.alphaComponent), forKey: .opacity)
        #else
        // For iOS, would use UIColor
        throw EncodingError.invalidValue(self, EncodingError.Context(
            codingPath: encoder.codingPath,
            debugDescription: "Color encoding not implemented for this platform"
        ))
        #endif
    }
}
