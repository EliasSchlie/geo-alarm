# GeoAlarm

iOS alarm app where alarms only ring when you're at a specific location. Set a time + place — the alarm activates only if you're physically within range at that time.

**Use cases:** Wake up call that only fires if you're still home. Reminder that triggers only when you arrive at the office. Location-aware recurring schedule.

## How It Works

1. Each alarm has a time, repeat schedule, and a map location with a configurable radius
2. iOS geofencing (`CLCircularRegion`) monitors when you enter/exit each location
3. **Enter region** → local notifications for that alarm's time are scheduled
4. **Exit region** → those notifications are cancelled
5. Result: the alarm fires only if you're at the location at the scheduled time

## Features

- **Location-bound alarms** — tap a map to set any location, adjust radius (default 200m)
- **Time + repeat schedule** — once, daily, weekdays, weekends, or custom days
- **6 alarm sounds** — Gentle, Soft, Chime, Classic, Radar, Urgent
- **5 durations** — 3s, 5s, 10s, 15s, 30s (Apple's notification sound limit)
- **Sound preview** — audition sounds before saving
- **Default sound settings** — set once, applied to new alarms automatically

## Tech Stack

| | |
|---|---|
| Language | Swift 5 |
| UI | SwiftUI |
| Persistence | SwiftData |
| Location | Core Location (CLCircularRegion geofencing) |
| Maps | MapKit |
| Notifications | UserNotifications (local) |
| Build | XcodeGen (`project.yml`) |
| iOS | 17.0+ |

## Requirements

- **"Always" location permission** — "When In Use" won't trigger geofence events in the background. The app shows a warning banner if this isn't granted.
- iOS 17+

## Building

```sh
# Generate Xcode project from project.yml
xcodegen generate

# Build for simulator (no signing needed)
xcodebuild -project GeoAlarm.xcodeproj -scheme GeoAlarm \
  -destination 'platform=iOS Simulator,name=iPhone 16' -quiet build
```

## Limitations

- iOS caps geofence monitoring at **20 regions** — max 20 alarms with locations
- Notification sounds max **30 seconds** — no infinite looping (Apple restriction)
- Requires **"Always" location permission** for background geofencing
