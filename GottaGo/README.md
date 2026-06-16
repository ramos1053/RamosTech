# GottaGo

Public restroom finder for iPhone and iPad. Built it because every app I tried only knew about dedicated restrooms. GottaGo also pulls from gas stations, hotels, restaurants, parks, malls, and airports — anywhere that has a toilet on the premises. Up to five live databases, one search, one-tap walking directions.

**Stack:** Swift · SwiftUI · MapKit · CoreLocation

---

## Data Sources

| Source | Coverage |
|---|---|
| [OpenStreetMap / Overpass](https://www.openstreetmap.org) | Global — dedicated facilities and venues with toilets |
| [Refuge Restrooms](https://www.refugerestrooms.org) | Global — gender-neutral and accessible focus |
| [Great British Toilet Map](https://www.toiletmap.org.uk) | UK — 14,000+ facilities |
| [Australia NTM](https://www.toiletmap.gov.au) | Australia — 17,000+ government-verified |
| [Wheelmap](https://wheelmap.org) *(optional)* | Global — wheelchair-accessible restrooms; strong North America coverage |

Wheelmap requires a free API key from [wheelmap.org/api](https://wheelmap.org/api). Set it in `ToiletDataService.swift` before building. Leave it empty and it's silently skipped.

---

## Features

- Interactive map (Standard / Satellite / Hybrid) with color-coded pins
- Filters: Free, Accessible, Gender Neutral
- Full-text search by name, address, or notes
- Street-level photos via [Mapillary](https://www.mapillary.com/developer) *(optional — free API key)*
- Add your own entries and submit to Refuge Restrooms
- Review any restroom — your own additions or anything pulled from the live databases
- Rate Refuge Restrooms entries directly (upvote/downvote sent back to their API)
- Favorites with one-tap walking navigation
- iCloud backup

---

## Build

See [`iOS/README.md`](iOS/README.md) for Xcode setup and sideload instructions.

---

[LICENSE](../LICENSE)
