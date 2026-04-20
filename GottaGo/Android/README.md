# GottaGo – Android

**Kotlin + Jetpack Compose** port of the GottaGo worldwide restroom finder.  
Feature-for-feature equivalent to the iOS version, using Google Maps instead of MapKit and SharedPreferences instead of UserDefaults.

---

## Features

- 4-tab navigation: **Home** (map + nearby list), **Nearby** (searchable full list), **Map** (full-screen), **Favorites**
- Live restroom data from 4 simultaneous APIs: OpenStreetMap/Overpass, Refuge Restrooms, Great British Toilet Map, Australia National Toilet Map
- Color-coded Google Maps pins (green = free, orange = paid, blue = unknown, pink = favorited)
- Filter chips: Free / Accessible / Gender Neutral
- Add a restroom (GPS pin or tap-on-map), optionally submit to Refuge Restrooms community database
- Favorite & un-favorite with swipe gestures; swipe to delete own entries
- One-tap navigation via the Google Maps app (walking directions)
- Review system (rating + cleanliness, 1–5)
- Material 3 dynamic color theme (Android 12+)

---

## Prerequisites

| Tool | Version |
|------|---------|
| Android Studio | Iguana (2024.1) or newer |
| JDK | 17+ (bundled with Android Studio) |
| Android Gradle Plugin | 8.4+ |
| Min Android | 8.0 (API 26) |
| Target Android | 14 (API 35) |
| Google Maps API key | Free tier at [console.cloud.google.com](https://console.cloud.google.com) |

---

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/ramos1053/RamosTech.git
cd RamosTech/GottaGo-Android
```

### 2. Get a Google Maps API key (free)

1. Go to [console.cloud.google.com](https://console.cloud.google.com) → **APIs & Services → Credentials**
2. Click **Create Credentials → API Key**
3. Click **Restrict Key**:
   - Application restrictions → **Android apps**
   - Add your package: `com.gottago.app` with your device's SHA-1 fingerprint
   - API restrictions → restrict to **Maps SDK for Android** only
4. Copy the key

### 3. Create `local.properties`

In the `GottaGo-Android/` root, copy the example and fill in your key:

```bash
cp local.properties.example local.properties
```

Edit `local.properties`:

```properties
MAPS_API_KEY=AIzaSy...your_real_key_here
sdk.dir=/Users/YourName/Library/Android/sdk
```

> `local.properties` is gitignored — your key is never committed.

### 4. Open in Android Studio

```
File → Open → select the GottaGo-Android/ folder
```

Android Studio will sync Gradle automatically. If it asks about the AGP upgrade, accept.

### 5. Run on an emulator or device

- **Emulator**: Create a device in the AVD Manager with **Google Play APIs** (required for Maps and location)
- **Physical device**: Enable Developer Options → USB Debugging; connect via USB; select the device from the toolbar
- Press **▶ Run** (Shift+F10)

---

## Building a Release APK for Sideloading

### Option A — Android Studio GUI

1. **Build → Generate Signed Bundle / APK**
2. Choose **APK**
3. Create or choose a keystore (keep the `.jks` file safe — you need it for future updates)
4. Choose **release** build variant → **Finish**
5. The signed APK appears in `app/release/app-release.apk`

### Option B — Command line

```bash
# Debug APK (fastest, for testing — installs directly)
./gradlew assembleDebug
# Output: app/build/outputs/apk/debug/app-debug.apk

# Release APK (requires signing)
./gradlew assembleRelease
# Output: app/build/outputs/apk/release/app-release-unsigned.apk
# Sign with apksigner or use the GUI above
```

---

## Sideloading the APK onto an Android Device

### Step 1 — Enable "Install Unknown Apps" on the target device

**Android 8+:**
1. Settings → Apps → Special App Access → Install Unknown Apps
2. Find the app you'll use to transfer the APK (Files, Chrome, etc.) → enable "Allow from this source"

**Android 12+ (alternate path):**
Settings → Privacy → Install Unknown Apps

### Step 2 — Transfer the APK

| Method | Steps |
|--------|-------|
| **USB** | Copy the `.apk` to the device via USB; open it in the Files app |
| **ADB** (fastest for testers) | `adb install app-debug.apk` |
| **Google Drive / Dropbox** | Upload APK → open the share link on the device → tap Download → tap the downloaded file |
| **Direct HTTP** | Host the APK on a local server; browse to it on the device |

### Step 3 — Install

Tap the `.apk` file in the Files app and follow the prompts. If prompted about Play Protect, tap **Install Anyway** (this is normal for sideloaded apps not in the Play Store).

### Step 4 — Trust the app

No extra steps needed — unlike iOS, Android does not require trusting a developer certificate after install.

---

## ADB Quick Reference (for testers with USB access)

```bash
# Check connected devices
adb devices

# Install (replaces existing)
adb install -r app-debug.apk

# Install to a specific device
adb -s DEVICE_SERIAL install -r app-debug.apk

# View live logcat (filter to GottaGo)
adb logcat | grep -i gottago

# Uninstall
adb uninstall com.gottago.app
```

---

## Project Structure

```
GottaGo-Android/
├── app/
│   ├── build.gradle.kts          # App-level build config + API key injection
│   └── src/main/
│       ├── AndroidManifest.xml
│       └── java/com/gottago/app/
│           ├── MainActivity.kt           # Entry point, location permission
│           ├── model/
│           │   └── Bathroom.kt           # Data classes, enums, sample data
│           ├── service/
│           │   └── ToiletDataService.kt  # All 4 API fetchers (OkHttp + Gson)
│           ├── data/
│           │   └── BathroomRepository.kt # SharedPreferences persistence
│           ├── viewmodel/
│           │   └── BathroomViewModel.kt  # Business logic, StateFlow
│           └── ui/
│               ├── theme/Theme.kt        # Material 3 green theme
│               ├── Components.kt         # Shared composables
│               ├── MainScreen.kt         # Bottom nav shell
│               ├── HomeScreen.kt         # Windowed map + nearby list
│               ├── MapScreen.kt          # Full-screen map
│               ├── NearbyScreen.kt       # Searchable sorted list
│               ├── FavoritesScreen.kt    # Favorites with swipe
│               ├── BathroomDetailSheet.kt # Detail + reviews
│               └── AddBathroomScreen.kt  # Add form + Refuge submission
├── gradle/
│   ├── libs.versions.toml        # Dependency version catalog
│   └── wrapper/
├── build.gradle.kts              # Project-level build config
├── settings.gradle.kts
├── local.properties.example      # Template — copy to local.properties
└── .gitignore
```

---

## Architecture

| Layer | Tech |
|-------|------|
| UI | Jetpack Compose + Material 3 |
| Map | Maps SDK for Android + Maps Compose |
| State | `StateFlow` + `derivedStateOf` (no Hilt — single ViewModel instance) |
| Network | OkHttp 4 + Gson |
| Storage | SharedPreferences + Gson serialization |
| Concurrency | Kotlin coroutines (`Dispatchers.IO` for network, `Dispatchers.Main` for UI) |
| Location | Fused Location Provider (`FusedLocationProviderClient`) |

---

## Data Sources

Same 4 sources as iOS (all free, open APIs):

- **OpenStreetMap / Overpass** — global dedicated toilets + any venue tagged `toilets=yes`
- **Refuge Restrooms** — gender-neutral and accessible, global
- **Great British Toilet Map** — UK, GraphQL
- **Australia National Toilet Map** — Australia, REST

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Map is blank / grey | Check `MAPS_API_KEY` in `local.properties`; make sure Maps SDK for Android is enabled in GCP |
| "This app is not optimized" warning | Normal on emulators without Play Services; use a Play-enabled AVD |
| Location never fires | Emulator: Extended Controls → Location → send a GPS fix; Device: ensure Location is enabled |
| `Unsupported class file major version` | Use JDK 17; File → Project Structure → SDK → JDK location |
| ADB: `no devices` | Ensure USB Debugging is on; try `adb kill-server && adb start-server` |

---

## Contributing

Same process as the iOS project — fork, branch, PR.

See the [root CONTRIBUTING guidelines](../README.md) for this repository.
