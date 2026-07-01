# GottaGo

GottaGo is a free, open-source iOS app for finding public restrooms anywhere in the world. It hits several live databases at once, pulls in restrooms attached to gas stations, hotels, restaurants and parks (not just dedicated public facilities), and lets you build a private favorites list with one-tap walking navigation.

## Map and navigation

The Home tab has a 300pt map preview; the Map tab gives you the full-screen version, switchable between Standard, Satellite, and Hybrid. Pins are color-coded — green for free, orange for paid, blue for unknown, pink for favorited — and a long press anywhere drops a new pin so you can add a restroom on the spot. Once you pick a destination, a walking route overlay shows ETA, distance, and a rough calorie estimate, and a "Locate Me" button snaps the map back to your position.

## Live data, queried simultaneously

| Source | Coverage | Notes |
|--------|----------|-------|
| OpenStreetMap / Overpass | Global | Dedicated `amenity=toilets` nodes plus any venue tagged `toilets=yes` — gas stations, hotels, restaurants, parks, stores, airports |
| Refuge Restrooms | Global | Community-curated, gender-neutral and accessible focus |
| Great British Toilet Map | United Kingdom | 14,000+ government-verified entries via GraphQL |
| Australia National Toilet Map | Australia | 17,000+ government-verified facilities via ArcGIS |
| Wheelmap (optional) | Global, strong North America coverage | Wheelchair-accessible restrooms. Needs a free API key from [wheelmap.org/api](https://wheelmap.org/api) — set `wheelmapAPIKey` in `ToiletDataService.swift` before building. |

Results get deduplicated by proximity so overlapping sources don't show the same toilet twice, and the app quietly refreshes in the background whenever you move more than a kilometer from wherever it last queried.

If you set a [Mapillary](https://www.mapillary.com/developer) access token (`mapillaryAccessToken` in `ToiletDataService.swift`), the detail sheet also shows a horizontal strip of nearby street-level photos. Leave it blank and the photo strip just doesn't appear — nothing else changes.

## Filtering and detail

Three filter chips — Free, Accessible, Gender Neutral — show up on the Home, Map, and List tabs. Tapping any pin or row opens a detail sheet with a mini map, the Mapillary photo strip (if configured), cost/hours/accessibility info, average rating and cleanliness scores, and buttons for Apple Maps directions or an in-app walking route.

You can review any restroom — your own entries or anything pulled from the live databases. A review is an overall rating, a cleanliness rating (both 1–5), and a free-text comment; for Refuge Restrooms entries, submitting a review also sends an upvote or downvote to their API. Reviews on API-sourced bathrooms save locally and persist across launches.

## Favorites and the nearby list

Heart a restroom from its detail sheet and it shows up immediately under Favorites, where you can reorder by dragging or swipe to un-favorite (or, for your own entries, delete permanently). Each favorite has its own one-tap route button. The Nearby list sorts everything by distance and has its own search bar and filter menu.

## Adding a restroom

Pick a category (public, restaurant, hotel, store, gas station, park, other), set the location using your current GPS position or by dropping a pin manually, mark the cost and any accessibility toggles, and add hours or notes if you want. There's an option to submit the entry to Refuge Restrooms as well, with live feedback on whether that submission succeeded.

## Where things are stored

Everything lives in `UserDefaults` locally, so it survives app restarts and updates. If you have a paid Apple Developer account, you can also enable iCloud Key-Value Store sync across devices — see the setup section below. You can delete your own entries at any time; entries pulled from the external APIs are read-only.

## Requirements

| Requirement | Version |
|-------------|---------|
| iOS | 17.0+ |
| Xcode | 15.0+ |
| Swift | 5.9+ |
| Apple Developer account | Free tier works for simulator/personal-device testing; iCloud sync needs a paid account |

### Optional API keys

Both are optional — the app works fine without either, they just unlock extra data.

| Key | Where to get it | What it enables |
|-----|-----------------|-----------------|
| `wheelmapAPIKey` | [wheelmap.org/api](https://wheelmap.org/api) | Wheelmap as a 5th data source |
| `mapillaryAccessToken` | [mapillary.com/developer](https://www.mapillary.com/developer) | Street-level photo strip on the detail screen |

Set them as string constants near the top of `ToiletDataService.swift` before building.

## Building from source

Clone the repository, then:

```bash
open GottaGo/iOS/GottaGo.xcodeproj
```

In the Project Navigator, select the GottaGo project (not the folder), go to the GottaGo target's **Signing & Capabilities**, and set **Team** to your own Apple ID — a free account is enough for simulator and personal-device testing.

For the simulator, pick an iOS 17+ device (iPhone 17 Pro or similar) and press ⌘R. For a real device, plug it in over USB, trust the computer, select it from the toolbar, and press ⌘R — Xcode handles signing and installation. On the phone, you'll need to go to Settings → General → VPN & Device Management and trust the developer certificate before it'll launch.

## Sideloading without a Mac

Three free options for getting the `.ipa` onto your phone without building it yourself:

**AltStore** — install AltStore on a PC or Mac, connect your iPhone over USB, grab the GottaGo `.ipa` from the Releases page, and import it from AltStore's `+` button. It re-signs the certificate automatically every 7 days (or use AltServer/AltStore PAL on a Mac for no expiration at all).

**SideStore** — same 7-day refresh model as AltStore, but works over Wi-Fi once you've done the initial setup.

**Sideloadly** — download it for Windows or macOS, connect your iPhone, drag the `.ipa` in, sign in with your Apple ID, and trust the resulting certificate under Settings → VPN & Device Management.

Free Apple IDs cap you at 3 sideloaded apps at a time, and they expire after 7 days and need re-signing. A paid developer account ($99/year) removes both limits.

### Enabling iCloud sync (needs a paid developer account)

Register an explicit App ID (`com.gottago.app`) at developer.apple.com under Identifiers, enable iCloud on it with Key-Value Storage checked, then uncomment the two iCloud lines in `GottaGo/GottaGo.entitlements`:

```xml
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)com.gottago.app</string>
```

Rebuild and you're done.

## Tech stack

| Component | Technology |
|-----------|-----------|
| UI | SwiftUI (iOS 17+) |
| Map | MapKit — `Map`, `Annotation`, `MapPolyline`, `MapStyle` |
| Location | CoreLocation / `CLLocationManager` |
| Networking | `URLSession` with async/await |
| Storage | `UserDefaults` plus `NSUbiquitousKeyValueStore` for iCloud |
| Concurrency | Swift structured concurrency — `async let`, `Task`, `@MainActor` |
| Architecture | MVVM (`ObservableObject` + `@EnvironmentObject`) |

## Data licensing

OpenStreetMap data is © OpenStreetMap contributors under [ODbL](https://www.openstreetmap.org/copyright). Refuge Restrooms and the Australian National Toilet Map are both [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The Great British Toilet Map is released under the [Open Government Licence](https://www.nationalarchives.gov.uk/doc/open-government-licence/). Wheelmap is [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) (it uses OSM data underneath), and Mapillary imagery is © Mapillary contributors, also [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

## Contributing

Pull requests are welcome — for anything big, open an issue first so we're on the same page before you put the work in.

## License

See the [LICENSE](../LICENSE) file at the repository root.
