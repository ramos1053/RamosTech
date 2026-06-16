# GottaGo

Public restroom finder for iPhone and iPad. Built it because every app I tried only knew about dedicated restrooms. GottaGo also pulls from gas stations, hotels, restaurants, parks, malls, and airports — anywhere that has a toilet on the premises. Four live databases, one search, one-tap walking directions.

**Stack:** Swift · SwiftUI · MapKit · CoreLocation

---

## Data Sources

| Source | Coverage |
|---|---|
| [OpenStreetMap / Overpass](https://www.openstreetmap.org) | Global — dedicated facilities and venues with toilets |
| [Refuge Restrooms](https://www.refugerestrooms.org) | Global — gender-neutral and accessible focus |
| [Great British Toilet Map](https://www.toiletmap.org.uk) | UK — 14,000+ facilities |
| [Australia National Toilet Map](https://www.toiletmap.gov.au) | Australia — 17,000+ government-verified |

---

## Features

- Interactive map (Standard / Satellite / Hybrid) with color-coded pins
- Filters: Free, Accessible, Gender Neutral
- Full-text search by name, address, or notes
- Add your own entries and optionally submit to Refuge Restrooms
- Favorites with one-tap walking navigation
- Reviews with overall and cleanliness ratings
- iCloud backup

---

## Build

See [`iOS/README.md`](iOS/README.md) for Xcode setup and sideload instructions.

---

[LICENSE](../LICENSE)
