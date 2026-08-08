# GoTransit MY

Flutter implementation of the GoTransit MY Figma UI.

## Implemented

- Splash, onboarding, login and registration screens
- 5-tab Material 3 app shell: Home, Routes, Stations, Alerts, Profile
- Route planner, route results, route details and fare estimate UI
- Nearby station list, station details, live arrival fallback labels and vehicle map mock
- Service alerts, alert details, notifications and statistics dashboard
- Profile, favourites/settings rows, language and dark mode affordances
- Demo Malaysian data with explicit `Live`, `Scheduled` and `Realtime unavailable` labels

## Run

```bash
cd gotransit_my
flutter pub get
flutter run
```

This is a UI/demo implementation. Firebase, GTFS feeds, OpenStreetMap tiles and official datasets should be connected through repositories in the next development pass.
