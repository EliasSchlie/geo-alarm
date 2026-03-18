# GeoAlarm

iOS app — time-based alarms that only ring at specific locations.

## Stack

SwiftUI, SwiftData, Core Location (geofencing), MapKit, UserNotifications. iOS 17+.

## Architecture

- **Models:** `Alarm` (SwiftData) — time, repeat days, location, radius, sound type/duration. `AlarmSound` — sound types + duration enums + defaults (UserDefaults)
- **Services:** `LocationManager` (geofencing), `NotificationManager` (local notifications), `AlarmCoordinator` (wires them together)
- **Views:** `AlarmListView`, `AlarmEditView`, `LocationPickerView`, `AlarmRingingView`, `SettingsView`

## How It Works

1. Each alarm has a location + radius → monitored as a `CLCircularRegion`
2. Enter region → schedule local notifications for that alarm's time
3. Exit region → cancel those notifications
4. Result: alarm only fires if you're at the location at the scheduled time

## Build

```sh
xcodegen generate   # regenerate .xcodeproj from project.yml
xcodebuild -project GeoAlarm.xcodeproj -scheme GeoAlarm -destination 'platform=iOS,id=00008101-000465C63AF0001E' -allowProvisioningUpdates -quiet build
xcrun devicectl device install app --device 00008101-000465C63AF0001E ~/Library/Developer/Xcode/DerivedData/GeoAlarm-bmhiuoofqntgofeayuccgyryzjpx/Build/Products/Debug-iphoneos/GeoAlarm.app
# Simulator build (compile check, no signing needed):
xcodebuild -project GeoAlarm.xcodeproj -scheme GeoAlarm -destination 'platform=iOS Simulator,id=4D08A167-2929-445D-ABE6-C8AA5FFD84B8' -quiet build
```

Team ID: Q2U8K9N3BL. Bundle ID: com.elias.geoalarm.
Device ID: 00008101-000465C63AF0001E (Elias' iPhone 12 Pro Max, iOS 18.5)

## Gotchas

- **Always regenerate xcodeproj** after changing `project.yml`: `xcodegen generate`
- **Verify resources are bundled** after build: `find ~/Library/Developer/Xcode/DerivedData/GeoAlarm-bmhiuoofqntgofeayuccgyryzjpx/Build/Products/Debug-iphoneos/GeoAlarm.app/ -name "*.caf" | wc -l` — XcodeGen resource config is fragile
- **SwiftData schema changes** delete existing data (app resets store on migration failure)
- **Sound files** use `type: folder` + `buildPhase: resources` in `project.yml` sources (not separate `resources:` key)
- **Custom notification sounds** need path relative to bundle root (e.g. `Sounds/classic_30s.caf`), not just filename
- **Geofence requires "Always" location** — "When In Use" won't trigger in background. App shows warning banner if not granted.
- **`requestState(for:)`** must be called after `startMonitoring(for:)` to handle "already inside region" case
- **Generate sounds** with Python: `python3` + `wave` module → `.wav` → `afconvert -f caff -d LEI16` → `.caf`

## Notes

- Swift 5 language mode is intentional — Swift 6 strict concurrency causes issues with CLLocationManagerDelegate

## Limits

- iOS caps monitored regions at 20
- Notification sounds max 30s (no infinite alarm loop — Apple reserves that)
- Needs "Always" location permission for background geofencing
