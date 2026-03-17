# GeoAlarm

iOS app — time-based alarms that only ring at specific locations.

## Stack

SwiftUI, SwiftData, Core Location (geofencing), MapKit, UserNotifications. iOS 17+.

## Architecture

- **Models:** `Alarm` (SwiftData) — time, repeat days, location, radius
- **Services:** `LocationManager` (geofencing), `NotificationManager` (local notifications), `AlarmCoordinator` (wires them together)
- **Views:** `AlarmListView`, `AlarmEditView`, `LocationPickerView`

## How It Works

1. Each alarm has a location + radius → monitored as a `CLCircularRegion`
2. Enter region → schedule local notifications for that alarm's time
3. Exit region → cancel those notifications
4. Result: alarm only fires if you're at the location at the scheduled time

## Build

```sh
xcodegen generate   # regenerate .xcodeproj from project.yml
```

Open `GeoAlarm.xcodeproj` in Xcode, select your iPhone, Run.

Team ID: Q2U8K9N3BL. Bundle ID: com.elias.geoalarm.

## Limits

- iOS caps monitored regions at 20
- Notification sounds max 30s (no infinite alarm loop — Apple reserves that)
- Needs "Always" location permission for background geofencing
