# GottaGo 🚻

**GottaGo** is a free, open-source iOS app that finds public restrooms near you — anywhere in the world. It queries multiple live databases simultaneously, surfaces venue restrooms (gas stations, hotels, restaurants, parks, and more), and lets you build a private favorites list with one-tap walking navigation.

---

## Features

### Map & Navigation
- **Interactive full-screen map** (Map tab) and a windowed 300 pt preview on the Home tab
- **Three map styles**: Standard, Satellite, and Hybrid — switchable mid-session
- **Color-coded pins**: green = free, orange = paid, blue = unknown, pink = favorited
- **Long-press anywhere** on the map to drop a pin and add a new restroom at that exact spot
- **Walking route overlay** with a live card showing ETA, distance (metric), and estimated calories burned
- **"Locate Me"** button re-centers the map on your current position instantly

### Live Worldwide Data (4 APIs, fired simultaneously)
| Source | Coverage | Notes |
|--------|----------|-------|
| **OpenStreetMap / Overpass** | Global | Dedicated `amenity=toilets` nodes/ways **+** any venue tagged `toilets=yes` (gas stations, hotels, restaurants, parks, stores, airports…) |
| **Refuge Restrooms** | Global | Community-curated gender-neutral and accessible restrooms |
| **Great British Toilet Map** | United Kingdom | 14,000+ gov-verified UK loos via GraphQL |
| **Australia National Toilet Map** | Australia | 17,000+ government-verified facilities |

- Results are **proximity-deduplicated** so overlapping sources never show the same toilet twice
- A spinner in the Home header shows when a background refresh is running
- Re-fetches automatically when you move more than 1 km from the last query point

### Filtering
Three one-tap filter chips (Home + Map + List tabs):
- **Free** — hides paid and unknown-cost entries
- **Accessible** — wheelchair-accessible only
- **Gender Neutral** — all-gender / unisex only

### Bathroom Detail Sheet
Tap any pin or row to open a detail sheet containing:
- **Mini map** centered on the facility
- **Info grid**: cost, hours, wheelchair access, gender-neutral status
- **Banners** for purchase-required and access-code entries
- **Average rating and cleanliness scores** (1–5 toilet icons, color-graded)
- **"Directions"** button — opens Apple Maps with walking directions
- **"Route"** button — draws a walking polyline on the in-app map
- **Reviews** section with full review history
- **Write a Review** — overall rating + cleanliness rating (1–5 toilet icons) + comment

### Favorites
- **Heart** any restroom from its detail sheet — appears immediately in the Favorites tab
- **Reorder** favorites by dragging the grip handle
- **Swipe trailing** to un-favorite; **swipe leading** to permanently delete (own entries only)
- **One-tap "Route"** button on each favorite row switches to the Map tab and draws the walking route
- Favorites count badge on the tab icon

### Nearby List
- Sorted by distance from your current location
- **Search bar** — filters by name, address, or notes in real time
- Filter menu (top-left) mirrors the chip bar
- Swipe to delete own entries

### Adding a Restroom
- **Category picker**: Public, Restaurant, Hotel, Store, Gas Station, Park, Other
- **Location**: use your current GPS position _or_ tap "Move Pin" to open a full-screen interactive location picker
- **Cost**: Free / Paid / Unknown (segmented control)
- **Toggles**: Wheelchair accessible, Gender-neutral, Purchase required
- **Access code field** (appears when purchase or paid is selected)
- **Hours** and free-text **Notes**
- **Community toggle**: optionally submit to [Refuge Restrooms](https://www.refugerestrooms.org) with live status feedback (Submitting → Success / Failed)

### Data Management
- **Local storage**: saved to `UserDefaults` (survives app restarts and updates)
- **iCloud Key-Value Store**: backup/restore across devices and after a phone wipe *(requires a paid Apple Developer account — see Setup)*
- **Delete** your own entries: swipe in List/Favorites, or tap the trash icon in the detail sheet (external API entries are read-only)

---

## Requirements

| Requirement | Version |
|-------------|---------|
| iOS | 17.0+ |
| Xcode | 15.0+ |
| Swift | 5.9+ |
| Apple Developer account | Free (Personal Team) — iCloud sync requires paid account |

---

## Building from Source

### 1. Clone the repository

```bash
git clone https://github.com/ramos1053/RamosTech.git
cd RamosTech
```

### 2. Open in Xcode

```bash
open GottaGo.xcodeproj
```

### 3. Select your team

1. In the Project Navigator, click **GottaGo** (the project, not the folder)
2. Select the **GottaGo** target → **Signing & Capabilities**
3. Under **Team**, choose your Apple ID (a free account works for simulator and personal-device testing)

### 4. Run on Simulator

Select **iPhone 17 Pro** (or any iOS 17+ simulator) from the device picker and press **⌘R**.

### 5. Run on a Real Device (USB)

1. Plug in your iPhone via USB and trust the computer
2. Select your device from the toolbar
3. Press **⌘R** — Xcode signs and installs automatically
4. On your iPhone: **Settings → General → VPN & Device Management** → trust your developer certificate

---

## Sideloading (No Xcode Required)

If you don't have a Mac, you can sideload a pre-built `.ipa` using one of these free tools:

### Option A — AltStore (Recommended)
1. Install [AltStore](https://altstore.io) on your PC or Mac
2. Connect your iPhone via USB and open AltStore on your PC/Mac
3. Download the GottaGo `.ipa` from the Releases page
4. In AltStore on your iPhone → **+** → choose the `.ipa`
5. AltStore refreshes the certificate automatically every 7 days (or use AltStore PAL / AltServer on a Mac for unlimited)

### Option B — SideStore (Wireless)
1. Install [SideStore](https://sidestore.io) — same 7-day refresh model but works over Wi-Fi after initial setup
2. Import the `.ipa` the same way as AltStore

### Option C — Sideloadly
1. Download [Sideloadly](https://sideloadly.io) (Windows or macOS)
2. Connect iPhone via USB
3. Drag the `.ipa` into Sideloadly, enter your Apple ID, click **Start**
4. Trust the certificate in **Settings → VPN & Device Management**

> **Note:** Free Apple IDs allow up to 3 apps sideloaded at a time. Apps expire after 7 days and must be re-signed. A paid Apple Developer account ($99/year) removes these limits.

### Enabling iCloud Sync (Optional — Paid Developer Account Only)

1. Sign in to [developer.apple.com](https://developer.apple.com) → **Identifiers**
2. Register an explicit App ID: `com.gottago.app`
3. Edit it → enable **iCloud** → check **iCloud Key-Value Storage** → Save
4. In `GottaGo/GottaGo.entitlements`, uncomment the two iCloud lines:
   ```xml
   <key>com.apple.developer.ubiquity-kvstore-identifier</key>
   <string>$(TeamIdentifierPrefix)com.gottago.app</string>
   ```
5. Rebuild

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| UI Framework | SwiftUI (iOS 17+) |
| Map | MapKit (`Map`, `Annotation`, `MapPolyline`, `MapStyle`) |
| Location | `CLLocationManager` / `CoreLocation` |
| Networking | `URLSession` async/await |
| Storage | `UserDefaults` + `NSUbiquitousKeyValueStore` (iCloud) |
| Concurrency | Swift structured concurrency (`async let`, `Task`, `@MainActor`) |
| Architecture | MVVM (`ObservableObject` + `@EnvironmentObject`) |

---

## Data Sources & Licensing

- **OpenStreetMap** data © OpenStreetMap contributors, [ODbL](https://www.openstreetmap.org/copyright)
- **Refuge Restrooms** — [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- **Great British Toilet Map** — [Open Government Licence](https://www.nationalarchives.gov.uk/doc/open-government-licence/)
- **Australian National Toilet Map** — [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/)

---

## Contributing

Pull requests are welcome. For major changes, open an issue first.

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit: `git commit -m "Add my feature"`
4. Push: `git push origin feature/my-feature`
5. Open a Pull Request

---

## License

This project is licensed under the terms in the [LICENSE](../LICENSE) file at the repository root.
