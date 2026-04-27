# GottaGo

A worldwide public restroom finder for **iOS**.

Find any restroom anywhere on Earth in seconds. GottaGo queries four live databases simultaneously (OpenStreetMap, Refuge Restrooms, Great British Toilet Map, and the Australian National Toilet Map), surfaces restrooms at gas stations, hotels, restaurants, parks, and more, and gets you there with one-tap walking directions.

---

## Platform

| Platform | Folder | Stack |
|----------|--------|-------|
| **iOS** (iPhone / iPad) | [`iOS/`](iOS/README.md) | Swift · SwiftUI · MapKit · CoreLocation |

---

## Features at a Glance

- Interactive map (Standard / Satellite / Hybrid) with color-coded pins
- Restrooms at dedicated facilities **and** at venues — gas stations, hotels, restaurants, parks, malls, airports, and more
- Filter by **Free**, **Accessible**, and **Gender Neutral**
- Full-text search by name, address, or notes
- Add your own entries — optionally submit to the Refuge Restrooms community database
- Favorite restrooms with one-tap walking navigation
- Reviews with overall + cleanliness ratings
- iCloud backup

---

## Data Sources

| Source | Coverage |
|--------|----------|
| [OpenStreetMap / Overpass](https://www.openstreetmap.org) | Global — dedicated toilets + venue toilets (`toilets=yes`) |
| [Refuge Restrooms](https://www.refugerestrooms.org) | Global — gender-neutral and accessible focus |
| [Great British Toilet Map](https://www.toiletmap.org.uk) | United Kingdom — 14,000+ facilities |
| [Australia National Toilet Map](https://www.toiletmap.gov.au) | Australia — 17,000+ government-verified |

---

## Quick Start

See [`iOS/README.md`](iOS/README.md) for Xcode build and sideload instructions.

---

## License

[LICENSE](../LICENSE) — repository root
