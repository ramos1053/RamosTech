# GottaGo

A worldwide public restroom finder for iOS. GottaGo queries multiple live databases at once — OpenStreetMap, Refuge Restrooms, the Great British Toilet Map, the Australian National Toilet Map, and optionally Wheelmap — and surfaces restrooms at gas stations, hotels, restaurants, parks, and anywhere else that has one, then gets you there with one-tap walking directions.

## Platform

| Platform | Folder | Stack |
|----------|--------|-------|
| iOS (iPhone / iPad) | [`iOS/`](iOS/README.md) | Swift, SwiftUI, MapKit, CoreLocation |

## What it does

The map view switches between Standard, Satellite, and Hybrid, with color-coded pins so you can tell at a glance which restrooms are free, paid, or unverified. You can filter by Free, Accessible, or Gender Neutral, search by name or address, and add your own entries — optionally contributing them back to the Refuge Restrooms community database. If you set a Mapillary API key, the detail sheet also shows nearby street-level photos. You can review any restroom, including ones pulled from the live databases — for Refuge Restrooms entries, a review also sends an upvote or downvote to their API. Favorites get one-tap navigation. iCloud backup for your favorites and reviews is built in, but the required entitlement ships commented out — see [`iOS/README.md`](iOS/README.md) for what it takes to turn it on.

## Data sources

| Source | Coverage |
|--------|----------|
| [OpenStreetMap / Overpass](https://www.openstreetmap.org) | Global — dedicated toilets and venues tagged `toilets=yes` |
| [Refuge Restrooms](https://www.refugerestrooms.org) | Global, gender-neutral and accessible focus |
| [Great British Toilet Map](https://www.toiletmap.org.uk) | UK — 14,000+ facilities |
| [Australia National Toilet Map](https://www.toiletmap.gov.au) | Australia — 17,000+ government-verified |
| [Wheelmap](https://wheelmap.org) (optional) | Global, strong North America coverage — wheelchair-accessible restrooms |

Wheelmap needs a free API key from [wheelmap.org/api](https://wheelmap.org/api), set in `ToiletDataService.swift` before building. Leave it blank and it's silently skipped. Mapillary works the same way with its own [developer token](https://www.mapillary.com/developer).

## Getting started

See [`iOS/README.md`](iOS/README.md) for the Xcode build and sideloading instructions.

## License

MIT — see [LICENSE](LICENSE).
