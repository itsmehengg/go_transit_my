# Module 3 – Station & Live Transport Tracking

## Implemented functions

- Official Malaysia GTFS Static station loading from `api.data.gov.my`
- Supported static feeds: KTMB, Rapid Rail KL and Rapid Bus KL
- Search stations by station/operator name
- Filter All / Rapid Rail KL / Rapid Bus KL / KTMB
- Android GPS permission and current-location detection
- Nearby-station ordering and distance calculation
- OpenStreetMap station map with current-location marker
- Official Malaysia GTFS Realtime vehicle-position loading
- Supported realtime feeds: KTMB, Rapid Bus KL and MRT Feeder Bus
- Live bus/train/rail markers with feed, route and update-time information where available
- Dynamic station details with operator, stop ID, coordinates and distance
- Favourite station toggle integrated with Module 1 personalisation storage
- Scheduled GTFS timetable for the selected stop
- Loading, pull-to-refresh, empty and error states

## Important data wording

Malaysia's official GTFS Realtime API currently provides **vehicle positions only**. It does not currently provide realtime arrival predictions, trip updates, or service alerts. For that reason, the timetable shown in Station Details comes from **GTFS Static scheduled stop times** and is clearly labelled `Scheduled`.

Rapid Rail realtime vehicle positions are intentionally not displayed because the official API currently documents that feed as not yet stable. Rapid Rail stations and scheduled timetable information still come from the official GTFS Static feed.

## Android test steps

```bash
git fetch origin
git checkout feature/module3-complete
git pull origin feature/module3-complete
flutter clean
flutter pub get
flutter analyze
flutter run
```

On first opening **Stations**, Android should request location permission. Choose **While using the app**. Ensure Location/GPS and Internet are enabled.

Test these flows:

1. Open Stations and allow location permission.
2. Confirm official stations load and nearest stations show a distance.
3. Search `KL Sentral`, `Bukit Bintang`, or another known station.
4. Switch between All / Rapid Rail KL / Rapid Bus KL / KTMB filters.
5. Open a station and confirm its real GTFS stop name, operator, stop ID and coordinates are shown.
6. Toggle Favourite, then return to Profile > Favourite Stations and confirm it is saved.
7. Open a station and wait for Scheduled Timetable to load.
8. Open Live Map and confirm current GTFS Realtime vehicle markers appear when feeds are available.
9. Pull to refresh and verify the page reloads without crashing.
10. Deny location permission once and confirm the module still loads stations alphabetically instead of crashing.

If an emulator has no GPS location configured, the module remains usable and shows a clear GPS warning.
