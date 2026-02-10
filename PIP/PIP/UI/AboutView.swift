//
//  AboutView.swift
//  PIP
//
//  Created by A. Ramos on 2025.
//  Copyright © 2025 RamosTech. All rights reserved.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 128, height: 128)
            }

            // App Name with tagline
            VStack(spacing: 8) {
                Text("PIP")
                    .font(.system(size: 32, weight: .bold))

                Text("Plain. Intuitive. Powerful.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Version info
            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                Text("Version \(version)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Divider()
                .padding(.horizontal, 40)

            // Copyright
            Text("Copyright © 2025 A. Ramos, RamosTech")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("All rights reserved.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(width: 400)
    }
}

#Preview {
    AboutView()
}
